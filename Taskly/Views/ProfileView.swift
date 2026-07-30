//
//  ProfileView.swift
//  Taskly
//

import SwiftUI
import SwiftData
import UserNotifications

struct ProfileView: View {
    @Bindable var profile: PlayerProfile

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @Query private var allTasks: [TaskItem]
    @Query private var rewards: [Reward]
    @Query private var focusSessions: [FocusSession]

    @State private var notifications = NotificationManager.shared
    @State private var isEditingName = false
    @State private var draftName = ""
    @State private var isConfirmingReset = false
    @State private var isManagingQuests = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    identityCard
                    lifetimeStats
                    achievementsSection
                    manageQuestsSection
                    notificationSection
                    upcomingAlerts
                    resetSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
            .tabBarClearance()
            .screenBackground()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .alert("What should we call you?", isPresented: $isEditingName) {
                TextField("Name", text: $draftName)
                Button("Save") {
                    let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { profile.displayName = trimmed }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Reset all progress?", isPresented: $isConfirmingReset) {
                Button("Reset everything", role: .destructive) { resetProgress() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes every quest, reward, focus session and your XP. It cannot be undone.")
            }
            .sheet(isPresented: $isManagingQuests) {
                QuestLibraryView(profile: profile)
            }
            .task { await notifications.refreshAuthorizationStatus() }
        }
    }

    // MARK: - Manage quests

    private var manageQuestsSection: some View {
        Button {
            Haptics.tap()
            isManagingQuests = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36)
                    .background {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Theme.accent.opacity(0.14))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Manage quests")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Search, edit, archive or restore")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .glassCard()
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Identity

    private var identityCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(profile.rank.gradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: profile.rank.tint.opacity(0.5), radius: 18)

                Image(systemName: profile.rank.symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Button {
                    draftName = profile.displayName
                    isEditingName = true
                } label: {
                    HStack(spacing: 6) {
                        Text(profile.displayName)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .buttonStyle(.pressable)

                Text("Level \(profile.level) · \(profile.rank.title)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(profile.rank.tint)
            }

            VStack(spacing: 7) {
                XPBar(progress: profile.levelProgress)
                HStack {
                    Text("\(profile.totalXP) XP total")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(profile.xpIntoLevel)/\(profile.xpForNextLevel) to next")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(20)
        .glassCard(radius: 26)
    }

    private var lifetimeStats: some View {
        HStack(spacing: 0) {
            stat("\(totalClears)", "clears", Theme.success)
            divider
            stat("\(profile.currentDayStreak)", "day streak", Theme.streak)
            divider
            stat("\(profile.bestDayStreak)", "best streak", Theme.gold)
            divider
            stat("\(profile.perfectDays)", "perfect days", Theme.accentAlt)
        }
        .padding(.vertical, 16)
        .glassCard()
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 26)
    }

    private func stat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var totalClears: Int {
        allTasks.reduce(0) { $0 + $1.totalCompletions }
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            let unlocked = Achievement.all.filter { $0.isUnlocked(profile: profile, tasks: allTasks) }
            SectionHeader(title: "Achievements", accessory: "\(unlocked.count)/\(Achievement.all.count)")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(Achievement.all) { achievement in
                    let isUnlocked = achievement.isUnlocked(profile: profile, tasks: allTasks)
                    VStack(spacing: 7) {
                        Image(systemName: isUnlocked ? achievement.symbol : "lock.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(isUnlocked ? AnyShapeStyle(achievement.tint) : AnyShapeStyle(Theme.textTertiary))
                            .frame(height: 26)
                        Text(achievement.title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(isUnlocked ? Theme.textPrimary : Theme.textTertiary)
                            .multilineTextAlignment(.center)
                        Text(achievement.detail)
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 8)
                    .glassCard(
                        radius: 16,
                        fill: isUnlocked ? achievement.tint.opacity(0.1) : Theme.surface.opacity(0.5)
                    )
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Notifications", subtitle: "Nudges for quests you haven't cleared")

            VStack(spacing: 0) {
                if notifications.authorizationStatus == .denied {
                    permissionBanner
                    Divider().overlay(Theme.hairline)
                } else if notifications.authorizationStatus == .notDetermined {
                    enableBanner
                    Divider().overlay(Theme.hairline)
                }

                toggleRow(
                    "All notifications",
                    symbol: "bell.fill",
                    isOn: $profile.notificationsEnabled
                )

                if profile.notificationsEnabled {
                    Divider().overlay(Theme.hairline)

                    toggleRow(
                        "Morning briefing",
                        subtitle: "What's on the board today",
                        symbol: "sunrise.fill",
                        isOn: $profile.morningBriefingEnabled
                    )

                    if profile.morningBriefingEnabled {
                        timeRow("Briefing time", minutes: $profile.morningBriefingMinutes)
                    }

                    Divider().overlay(Theme.hairline)

                    toggleRow(
                        "Evening nudge",
                        subtitle: "Lists what's still unfinished",
                        symbol: "moon.stars.fill",
                        isOn: $profile.eveningNudgeEnabled
                    )

                    if profile.eveningNudgeEnabled {
                        timeRow("Nudge time", minutes: $profile.eveningNudgeMinutes)
                    }

                    Divider().overlay(Theme.hairline)

                    toggleRow(
                        "Streak warnings",
                        subtitle: "Late alert when a streak is about to break",
                        symbol: "flame.fill",
                        isOn: $profile.streakAlertsEnabled
                    )

                    Divider().overlay(Theme.hairline)

                    toggleRow(
                        "Encouragement",
                        subtitle: "Upbeat check-ins through the day",
                        symbol: "hand.thumbsup.fill",
                        isOn: $profile.encouragementEnabled
                    )

                    if profile.encouragementEnabled {
                        cadenceRow
                    }

                    Divider().overlay(Theme.hairline)

                    toggleRow(
                        "Build expiry",
                        subtitle: buildExpirySubtitle,
                        symbol: "hammer.fill",
                        isOn: $profile.buildExpiryAlertsEnabled
                    )
                }
            }
            .glassCard()
        }
    }

    private var permissionBanner: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications are turned off")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Tap to enable them in Settings")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }

    private var enableBanner: some View {
        Button {
            Task {
                Haptics.tap()
                await notifications.requestAuthorization()
                notifications.scheduleRefresh(tasks: allTasks.filter { !$0.isArchived }, profile: profile)
            }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Turn on reminders")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Taskly will ping you about unfinished quests")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(_ title: String, subtitle: String? = nil, symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn.animation(.spring(response: 0.3, dampingFraction: 0.85))) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .tint(Theme.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var cadenceRow: some View {
        HStack(spacing: 7) {
            cadenceChip("Light", count: 2)
            cadenceChip("Steady", count: 3)
            cadenceChip("Frequent", count: 5)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .padding(.leading, 31)
    }

    private func cadenceChip(_ label: String, count: Int) -> some View {
        let isSelected = profile.encouragementPingsPerDay == count

        return Button {
            Haptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                profile.encouragementPingsPerDay = count
            }
        } label: {
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text("\(count)/day")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .opacity(0.7)
            }
            .foregroundStyle(isSelected ? Color.black.opacity(0.85) : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.06)))
            }
        }
        .buttonStyle(.pressable)
    }

    /// Doubles as the countdown readout, since this is the only place the build's
    /// remaining life is visible.
    private var buildExpirySubtitle: String {
        guard let expiry = BuildExpiryReader.current() else {
            return "Couldn't read this build's signing date"
        }
        if expiry.isExpired() {
            return "This build has expired · rebuild from Xcode"
        }

        let days = expiry.daysRemaining()
        let when = expiry.expiresAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let estimate = expiry.source == .buildDateEstimate ? " (estimated)" : ""

        if days == 0 { return "Expires today\(estimate) · rebuild from Xcode" }
        return "\(days) \(days == 1 ? "day" : "days") left · \(when)\(estimate)"
    }

    private func timeRow(_ label: String, minutes: Binding<Int>) -> some View {
        let binding = Binding<Date>(
            get: { PlayerProfile.date(fromMinutes: minutes.wrappedValue) },
            set: { minutes.wrappedValue = PlayerProfile.minutes(from: $0) }
        )

        return DatePicker(selection: binding, displayedComponents: .hourAndMinute) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 31)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Upcoming alerts preview

    private var upcomingAlerts: some View {
        let plan = notifications
            .buildPlan(tasks: allTasks.filter { !$0.isArchived }, profile: profile)
            .prefix(5)

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Next alerts", accessory: plan.isEmpty ? nil : "\(plan.count)")

            if plan.isEmpty {
                EmptyStateCard(
                    symbol: "bell.slash",
                    title: "Nothing scheduled",
                    message: profile.notificationsEnabled
                        ? "Add a reminder to a quest and it'll show up here."
                        : "Notifications are switched off."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(plan)) { item in
                        HStack(spacing: 11) {
                            Image(systemName: symbol(for: item.kind))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(tint(for: item.kind))
                                .frame(width: 28, height: 28)
                                .background {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(tint(for: item.kind).opacity(0.14))
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Text(item.body)
                                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.textTertiary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            Text(relativeTime(item.fireDate))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)

                        if item.id != plan.last?.id {
                            Divider().overlay(Theme.hairline).padding(.leading, 14)
                        }
                    }
                }
                .glassCard()
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return date.formatted(.dateTime.hour().minute()) }
        if calendar.isDateInTomorrow(date) { return "Tmrw \(date.formatted(.dateTime.hour().minute()))" }
        return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private func symbol(for kind: PlannedNotification.Kind) -> String {
        switch kind {
        case .questReminder: "bell.fill"
        case .morningBriefing: "sunrise.fill"
        case .eveningNudge: "moon.stars.fill"
        case .overdue: "exclamationmark.triangle.fill"
        case .streakAlert: "flame.fill"
        case .encouragement: "hand.thumbsup.fill"
        case .buildExpiry: "hammer.fill"
        }
    }

    private func tint(for kind: PlannedNotification.Kind) -> Color {
        switch kind {
        case .questReminder: Theme.accent
        case .morningBriefing: Theme.warning
        case .eveningNudge: Theme.accentAlt
        case .overdue: Theme.danger
        case .streakAlert: Theme.streak
        case .encouragement: Theme.success
        case .buildExpiry: Theme.warning
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        Button {
            Haptics.warning()
            isConfirmingReset = true
        } label: {
            Label("Reset all progress", systemImage: "arrow.counterclockwise")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassCard(radius: 16, fill: Theme.danger.opacity(0.08))
        }
        .buttonStyle(.pressable)
    }

    private func resetProgress() {
        for task in allTasks { context.delete(task) }
        for reward in rewards { context.delete(reward) }
        for session in focusSessions { context.delete(session) }
        profile.totalXP = 0
        profile.currentDayStreak = 0
        profile.bestDayStreak = 0
        profile.perfectDays = 0
        profile.lastPerfectDay = nil
        profile.lastActiveDay = nil
        profile.coins = 0
        profile.lifetimeCoins = 0
        profile.coinsSpent = 0
        profile.focusedSecondsTotal = 0
        notifications.cancelAll()
        Haptics.success()
    }
}

// MARK: - Achievements

struct Achievement: Identifiable {
    var id: String { title }
    var title: String
    var detail: String
    var symbol: String
    var tint: Color
    var isUnlocked: (PlayerProfile, [TaskItem]) -> Bool

    func isUnlocked(profile: PlayerProfile, tasks: [TaskItem]) -> Bool {
        isUnlocked(profile, tasks)
    }

    static let all: [Achievement] = [
        Achievement(title: "First Steps", detail: "Clear 1 quest", symbol: "figure.walk", tint: Theme.success) { _, tasks in
            tasks.reduce(0) { $0 + $1.totalCompletions } >= 1
        },
        Achievement(title: "Getting Going", detail: "Clear 25 quests", symbol: "flag.fill", tint: Theme.accent) { _, tasks in
            tasks.reduce(0) { $0 + $1.totalCompletions } >= 25
        },
        Achievement(title: "Centurion", detail: "Clear 100 quests", symbol: "shield.fill", tint: Theme.accentAlt) { _, tasks in
            tasks.reduce(0) { $0 + $1.totalCompletions } >= 100
        },
        Achievement(title: "On Fire", detail: "7 day streak", symbol: "flame.fill", tint: Theme.streak) { profile, _ in
            profile.bestDayStreak >= 7
        },
        Achievement(title: "Unstoppable", detail: "30 day streak", symbol: "bolt.fill", tint: Theme.warning) { profile, _ in
            profile.bestDayStreak >= 30
        },
        Achievement(title: "Flawless", detail: "5 perfect days", symbol: "crown.fill", tint: Theme.gold) { profile, _ in
            profile.perfectDays >= 5
        },
        Achievement(title: "Scholar", detail: "50 study clears", symbol: "book.fill", tint: TaskCategory.study.tint) { _, tasks in
            tasks.filter { $0.category == .study }.reduce(0) { $0 + $1.totalCompletions } >= 50
        },
        Achievement(title: "Shipper", detail: "50 build clears", symbol: "hammer.fill", tint: TaskCategory.build.tint) { _, tasks in
            tasks.filter { $0.category == .build }.reduce(0) { $0 + $1.totalCompletions } >= 50
        },
        Achievement(title: "Legend", detail: "Reach level 25", symbol: "sparkles", tint: Color(hex: 0x5CF2E5)) { profile, _ in
            profile.level >= 25
        }
    ]
}
