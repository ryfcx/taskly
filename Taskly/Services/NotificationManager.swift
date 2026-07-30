//
//  NotificationManager.swift
//  Taskly
//

import Foundation
import UserNotifications

/// A fully resolved notification ready to hand to the system. Built on the main actor from
/// SwiftData models, then scheduled off it — so no model objects cross actor boundaries.
struct PlannedNotification: Sendable, Identifiable {
    enum Kind: String, Sendable {
        case questReminder = "quest"
        case morningBriefing = "briefing"
        case eveningNudge = "nudge"
        case overdue = "overdue"
        case streakAlert = "streak"
        case encouragement = "cheer"
        case buildExpiry = "build"
    }

    var id: String
    var kind: Kind
    var title: String
    var body: String
    var fireDate: Date
    var isTimeSensitive: Bool = false
}

@MainActor
@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    /// iOS only keeps 64 pending local notifications, so we stay comfortably under it.
    private static let pendingLimit = 56
    /// How many future occurrences of each recurring reminder we queue up.
    private static let occurrencesPerQuest = 3
    /// How many days ahead the digest notifications are planned.
    private static let digestHorizon = 7
    /// Encouragement pings only cover today and tomorrow; any further out and the counts
    /// they quote would be stale by the time they fire.
    private static let encouragementHorizon = 2
    /// Only warn about the signature this close to expiry, so a year long developer
    /// profile stays quiet instead of parking three alerts a year out.
    private static let buildExpiryWarningDays = 14

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var pendingCount: Int = 0

    private var refreshTask: Task<Void, Never>?

    private init() {}

    // MARK: - Permission

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    // MARK: - Scheduling

    /// Rebuilds the whole notification queue from the current board. Debounced so a burst of
    /// edits (or rapid completions) only results in one rescheduling pass.
    func scheduleRefresh(tasks: [TaskItem], profile: PlayerProfile) {
        let plan = buildPlan(tasks: tasks, profile: profile)
        let enabled = profile.notificationsEnabled

        refreshTask?.cancel()
        refreshTask = Task { [plan] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self.apply(plan: enabled ? plan : [])
        }
    }

    /// Builds the plan synchronously. Exposed for previews, tests and the settings screen.
    /// `buildExpiry` is injectable so tests do not depend on how this copy was signed.
    func buildPlan(
        tasks: [TaskItem],
        profile: PlayerProfile,
        now: Date = Date(),
        buildExpiry: BuildExpiry? = nil
    ) -> [PlannedNotification] {
        guard profile.notificationsEnabled else { return [] }

        let calendar = Calendar.current
        var plan: [PlannedNotification] = []

        plan += questReminders(tasks: tasks, now: now, calendar: calendar)
        plan += overdueAlerts(tasks: tasks, now: now, calendar: calendar)
        plan += digestNotifications(tasks: tasks, profile: profile, now: now, calendar: calendar)
        plan += encouragementPings(tasks: tasks, profile: profile, now: now, calendar: calendar)
        plan += buildExpiryAlerts(
            profile: profile,
            now: now,
            calendar: calendar,
            expiry: buildExpiry ?? BuildExpiryReader.current()
        )

        return plan
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
    }

    private func questReminders(tasks: [TaskItem], now: Date, calendar: Calendar) -> [PlannedNotification] {
        tasks.filter(\.reminderEnabled).flatMap { task -> [PlannedNotification] in
            let dates = task.nextReminderDates(limit: Self.occurrencesPerQuest, from: now, calendar: calendar)
            return dates.enumerated().map { index, date in
                PlannedNotification(
                    id: "\(PlannedNotification.Kind.questReminder.rawValue).\(task.id.uuidString).\(index)",
                    kind: .questReminder,
                    title: task.title,
                    body: reminderBody(for: task),
                    fireDate: date
                )
            }
        }
    }

    private func reminderBody(for task: TaskItem) -> String {
        let xp = QuestEngine.projectedXP(for: task)
        if task.currentStreak >= 3 {
            return "\(task.currentStreak) day streak on the line · +\(xp) XP"
        }
        return "\(task.category.title) quest · +\(xp) XP waiting"
    }

    private func overdueAlerts(tasks: [TaskItem], now: Date, calendar: Calendar) -> [PlannedNotification] {
        tasks.compactMap { task in
            guard task.recurrence == .once,
                  !task.isArchived,
                  task.lastCompletedDay == nil,
                  let due = task.dueDate else { return nil }

            // Nudge at the due time itself, or mid-morning if the due date has no useful time.
            let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due
            guard fire > now else { return nil }

            return PlannedNotification(
                id: "\(PlannedNotification.Kind.overdue.rawValue).\(task.id.uuidString)",
                kind: .overdue,
                title: "Due today: \(task.title)",
                body: "This one-off quest expires tonight · +\(QuestEngine.projectedXP(for: task)) XP",
                fireDate: fire,
                isTimeSensitive: true
            )
        }
    }

    /// Morning briefings and evening "you still have unfinished quests" alerts, planned a week out.
    /// Counts are baked in per day, which is why the whole queue is rebuilt on every change.
    private func digestNotifications(
        tasks: [TaskItem],
        profile: PlayerProfile,
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        var plan: [PlannedNotification] = []
        let today = calendar.startOfDay(for: now)

        for offset in 0..<Self.digestHorizon {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { break }
            let scheduled = QuestEngine.tasks(tasks, scheduledOn: day, calendar: calendar)
            guard !scheduled.isEmpty else { continue }

            // Today's counts reflect what is actually left; future days assume nothing is done yet.
            let outstanding = offset == 0
                ? scheduled.filter { !$0.isCompleted(on: day, calendar: calendar) }
                : scheduled
            let xp = outstanding.reduce(0) { $0 + QuestEngine.projectedXP(for: $1) }
            let dayKey = Self.dayKey(day, calendar: calendar)

            if profile.morningBriefingEnabled, !outstanding.isEmpty,
               let fire = time(profile.morningBriefingMinutes, on: day, calendar: calendar), fire > now {
                plan.append(
                    PlannedNotification(
                        id: "\(PlannedNotification.Kind.morningBriefing.rawValue).\(dayKey)",
                        kind: .morningBriefing,
                        title: offset == 0 ? "Today's board is set" : "Tomorrow's board is set",
                        body: "\(outstanding.count) \(Self.questWord(outstanding.count)) lined up · \(xp) XP up for grabs",
                        fireDate: fire
                    )
                )
            }

            if profile.eveningNudgeEnabled, !outstanding.isEmpty,
               let fire = time(profile.eveningNudgeMinutes, on: day, calendar: calendar), fire > now {
                plan.append(
                    PlannedNotification(
                        id: "\(PlannedNotification.Kind.eveningNudge.rawValue).\(dayKey)",
                        kind: .eveningNudge,
                        title: "\(outstanding.count) \(Self.questWord(outstanding.count)) unfinished",
                        body: eveningBody(outstanding: outstanding, xp: xp, profile: profile, isToday: offset == 0),
                        fireDate: fire,
                        isTimeSensitive: true
                    )
                )
            }
        }

        if profile.streakAlertsEnabled, profile.currentDayStreak >= 2 {
            let scheduledToday = QuestEngine.tasks(tasks, scheduledOn: today, calendar: calendar)
            let doneToday = scheduledToday.contains { $0.isCompleted(on: today, calendar: calendar) }
            if !doneToday, let fire = time(21 * 60 + 30, on: today, calendar: calendar), fire > now {
                plan.append(
                    PlannedNotification(
                        id: "\(PlannedNotification.Kind.streakAlert.rawValue).\(Self.dayKey(today, calendar: calendar))",
                        kind: .streakAlert,
                        title: "Your \(profile.currentDayStreak) day streak ends at midnight",
                        body: "Clear one quest to keep it alive.",
                        fireDate: fire,
                        isTimeSensitive: true
                    )
                )
            }
        }

        return plan
    }

    /// Upbeat check-ins through the middle of the day, so the board is not only mentioned
    /// at breakfast and bedtime. A cleared board earns silence rather than another ping.
    private func encouragementPings(
        tasks: [TaskItem],
        profile: PlayerProfile,
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        guard profile.encouragementEnabled else { return [] }
        let slots = Self.encouragementSlots(profile: profile)
        guard !slots.isEmpty else { return [] }

        var plan: [PlannedNotification] = []
        let today = calendar.startOfDay(for: now)

        for offset in 0..<Self.encouragementHorizon {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { break }
            let scheduled = QuestEngine.tasks(tasks, scheduledOn: day, calendar: calendar)
            guard !scheduled.isEmpty else { continue }

            let outstanding = offset == 0
                ? scheduled.filter { !$0.isCompleted(on: day, calendar: calendar) }
                : scheduled
            guard !outstanding.isEmpty else { continue }

            let xp = outstanding.reduce(0) { $0 + QuestEngine.projectedXP(for: $1) }
            let dayKey = Self.dayKey(day, calendar: calendar)
            let dayNumber = calendar.component(.day, from: day)

            for (index, minutes) in slots.enumerated() {
                guard let fire = time(minutes, on: day, calendar: calendar), fire > now else { continue }

                let message = Encouragement.message(
                    done: scheduled.count - outstanding.count,
                    total: scheduled.count,
                    remainingTitles: outstanding.map(\.title),
                    xp: xp,
                    streak: profile.currentDayStreak,
                    seed: dayNumber * slots.count + index
                )

                plan.append(
                    PlannedNotification(
                        id: "\(PlannedNotification.Kind.encouragement.rawValue).\(dayKey).\(index)",
                        kind: .encouragement,
                        title: message.title,
                        body: message.body,
                        fireDate: fire
                    )
                )
            }
        }

        return plan
    }

    /// Spread the pings evenly across the middle of the day, staying clear of the briefing
    /// and the evening nudge so no part of the day gets two alerts at once.
    private static func encouragementSlots(profile: PlayerProfile) -> [Int] {
        let count = min(max(profile.encouragementPingsPerDay, 0), 6)
        guard count > 0 else { return [] }

        let start = min(profile.morningBriefingMinutes + 120, 13 * 60)
        let end = max(profile.eveningNudgeMinutes - 60, start + 60)
        let step = (end - start) / count
        return (0..<count).map { start + step * $0 + step / 2 }
    }

    /// Free Apple developer signatures last a week, so warn while there is still time to
    /// plug in and rebuild rather than after the app has stopped launching.
    private func buildExpiryAlerts(
        profile: PlayerProfile,
        now: Date,
        calendar: Calendar,
        expiry: BuildExpiry?
    ) -> [PlannedNotification] {
        guard profile.buildExpiryAlertsEnabled,
              let expiry,
              !expiry.isExpired(at: now),
              expiry.daysRemaining(from: now) <= Self.buildExpiryWarningDays
        else { return [] }

        let expiryDay = calendar.startOfDay(for: expiry.expiresAt)

        return [2, 1, 0].compactMap { lead in
            guard let day = calendar.date(byAdding: .day, value: -lead, to: expiryDay),
                  let fire = time(10 * 60, on: day, calendar: calendar),
                  fire > now,
                  fire < expiry.expiresAt
            else { return nil }

            return PlannedNotification(
                id: "\(PlannedNotification.Kind.buildExpiry.rawValue).\(Self.dayKey(day, calendar: calendar))",
                kind: .buildExpiry,
                title: Self.buildExpiryTitle(lead: lead),
                body: Self.buildExpiryBody(lead: lead, expiry: expiry),
                fireDate: fire,
                isTimeSensitive: lead <= 1
            )
        }
    }

    private static func buildExpiryTitle(lead: Int) -> String {
        switch lead {
        case 0: "Taskly's 7 day build expires today"
        case 1: "Taskly's build expires tomorrow"
        default: "Taskly's build expires in \(lead) days"
        }
    }

    private static func buildExpiryBody(lead: Int, expiry: BuildExpiry) -> String {
        guard lead > 0 else {
            return "Plug in and hit Run in Xcode to sign it for another 7 days. Your quests, XP and streaks stay put."
        }
        let when = expiry.expiresAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let estimate = expiry.source == .buildDateEstimate ? " (estimated)" : ""
        return "Rebuild from Xcode before \(when)\(estimate) so your streak doesn't stall."
    }

    private func eveningBody(outstanding: [TaskItem], xp: Int, profile: PlayerProfile, isToday: Bool) -> String {
        let names = outstanding.prefix(3).map(\.title).joined(separator: ", ")
        let extra = outstanding.count > 3 ? " +\(outstanding.count - 3) more" : ""
        if isToday, profile.currentDayStreak >= 2 {
            return "\(names)\(extra) · \(xp) XP and a \(profile.currentDayStreak) day streak on the line"
        }
        return "\(names)\(extra) · \(xp) XP still on the table"
    }

    private func time(_ minutes: Int, on day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)
    }

    private static func dayKey(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private static func questWord(_ count: Int) -> String {
        count == 1 ? "quest" : "quests"
    }

    // MARK: - Delivery

    private func apply(plan: [PlannedNotification]) async {
        let center = UNUserNotificationCenter.current()
        // Leave the live focus timer alone; it is managed separately by FocusView.
        let pending = await center.pendingNotificationRequests()
        let removable = pending
            .map(\.identifier)
            .filter { $0 != Self.focusAlertID }
        center.removePendingNotificationRequests(withIdentifiers: removable)

        guard !plan.isEmpty else {
            pendingCount = await center.pendingNotificationRequests().count
            return
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            pendingCount = await center.pendingNotificationRequests().count
            return
        }

        let calendar = Calendar.current
        for item in plan.prefix(Self.pendingLimit) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.threadIdentifier = item.kind.rawValue
            content.interruptionLevel = item.isTimeSensitive ? .timeSensitive : .active

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)

            try? await center.add(request)
        }

        pendingCount = await center.pendingNotificationRequests().count
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        pendingCount = 0
    }

    // MARK: - Focus session alert

    /// Kept outside the digest rebuild so pausing and resuming a session does not wipe the
    /// rest of the day's reminders, and so a digest refresh does not cancel the timer.
    private static let focusAlertID = "focus.session.end"

    func scheduleFocusAlert(endsAt: Date, questTitle: String, coins: Int, xp: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.focusAlertID])

        guard endsAt > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = questTitle.isEmpty ? "Focus time's up" : "\(questTitle) · time's up"
        content.body = "Bank +\(coins) \(coins == 1 ? "coin" : "coins") and +\(xp) XP, or keep going."
        content.sound = .default
        content.threadIdentifier = "focus"
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: endsAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.focusAlertID, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelFocusAlert() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.focusAlertID])
    }
}
