//
//  TaskItem.swift
//  Taskly
//

import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var categoryRaw: String = TaskCategory.routine.rawValue
    var difficultyRaw: String = TaskDifficulty.easy.rawValue
    var recurrenceRaw: String = RecurrenceKind.daily.rawValue
    /// Bitfield of active weekdays, only meaningful when `recurrence == .weekly`.
    var weekdayMask: Int = Weekdays.all
    var dueDate: Date?
    var reminderEnabled: Bool = false
    /// Minutes past midnight, avoids storing a full `Date` for a time-of-day value.
    var reminderMinutes: Int = 8 * 60
    var iconName: String = "checkmark.seal.fill"
    var createdAt: Date = Date()
    /// First day this quest is allowed on the board, so a quest can be queued for tomorrow
    /// or later. Nil means it starts the day it was created.
    var startDay: Date?
    var isArchived: Bool = false
    var sortIndex: Int = 0

    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var totalCompletions: Int = 0
    var lastCompletedDay: Date?

    @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.task)
    var completions: [CompletionRecord] = []

    init(
        title: String,
        notes: String = "",
        category: TaskCategory = .routine,
        difficulty: TaskDifficulty = .easy,
        recurrence: RecurrenceKind = .daily,
        weekdayMask: Int = Weekdays.all,
        dueDate: Date? = nil,
        reminderEnabled: Bool = false,
        reminderMinutes: Int = 8 * 60,
        iconName: String? = nil,
        startDay: Date? = nil,
        sortIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.categoryRaw = category.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.recurrenceRaw = recurrence.rawValue
        self.weekdayMask = weekdayMask
        self.dueDate = dueDate
        self.reminderEnabled = reminderEnabled
        self.reminderMinutes = reminderMinutes
        self.iconName = iconName ?? category.symbol
        self.createdAt = Date()
        self.startDay = startDay.map { Calendar.current.startOfDay(for: $0) }
        self.sortIndex = sortIndex
    }
}

// MARK: - Typed accessors

extension TaskItem {
    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var difficulty: TaskDifficulty {
        get { TaskDifficulty(rawValue: difficultyRaw) ?? .easy }
        set { difficultyRaw = newValue.rawValue }
    }

    var recurrence: RecurrenceKind {
        get { RecurrenceKind(rawValue: recurrenceRaw) ?? .daily }
        set { recurrenceRaw = newValue.rawValue }
    }

    var reminderTimeComponents: DateComponents {
        DateComponents(hour: reminderMinutes / 60, minute: reminderMinutes % 60)
    }

    /// The reminder time expressed as a `Date` today, for use with `DatePicker`.
    var reminderDate: Date {
        Calendar.current.date(
            bySettingHour: reminderMinutes / 60,
            minute: reminderMinutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    var scheduleSummary: String {
        switch recurrence {
        case .daily: "Every day"
        case .weekly: Weekdays.summary(for: weekdayMask)
        case .once: dueDate.map { "By \($0.formatted(.dateTime.month(.abbreviated).day()))" } ?? "One time"
        }
    }
}

// MARK: - Start day

extension TaskItem {
    /// The first day this quest can appear, falling back to its creation day for quests
    /// saved before start days existed.
    func firstActiveDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: startDay ?? createdAt)
    }

    /// True while the quest is still queued for a later day and not on today's board yet.
    var isQueuedForLater: Bool {
        let calendar = Calendar.current
        return firstActiveDay(calendar: calendar) > calendar.startOfDay(for: Date())
    }

    /// A short label such as "Tomorrow" or "Thu, Jul 30" for a quest that hasn't started.
    var startDayLabel: String? {
        guard isQueuedForLater else { return nil }
        let day = firstActiveDay()
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

// MARK: - Scheduling

extension TaskItem {
    /// Whether the recurrence pattern alone puts this quest on the given day,
    /// ignoring whether a one-off has already been finished.
    func matchesPattern(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard day >= firstActiveDay(calendar: calendar) else { return false }

        switch recurrence {
        case .daily:
            return true
        case .weekly:
            let index = calendar.component(.weekday, from: day) - 1
            return Weekdays.contains(weekdayMask, weekdayIndex: index)
        case .once:
            return true
        }
    }

    /// Whether this quest should appear on the board for the given day.
    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        guard !isArchived else { return false }
        let day = calendar.startOfDay(for: date)

        // A finished one-off drops off the board but stays visible on the day it was cleared.
        if recurrence == .once, let completed = lastCompletedDay {
            return calendar.isDate(day, inSameDayAs: completed)
        }
        return matchesPattern(on: day, calendar: calendar)
    }

    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        if let last = lastCompletedDay, calendar.isDate(last, inSameDayAs: date) { return true }
        return completions.contains { calendar.isDate($0.day, inSameDayAs: date) }
    }

    /// Cleared for real — not a skip. Used for streaks, XP stats and perfect days.
    func isCleared(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let record = completion(on: date, calendar: calendar) else {
            if let last = lastCompletedDay, calendar.isDate(last, inSameDayAs: date) { return true }
            return false
        }
        return !record.wasSkipped
    }

    func isSkipped(on date: Date, calendar: Calendar = .current) -> Bool {
        completion(on: date, calendar: calendar)?.wasSkipped == true
    }

    func completion(on date: Date, calendar: Calendar = .current) -> CompletionRecord? {
        completions.first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    var isOverdue: Bool {
        guard recurrence == .once, let dueDate, lastCompletedDay == nil else { return false }
        return Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: Date())
    }

    /// The most recent day before `day` that this quest was expected on.
    func previousScheduledDay(before day: Date, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: day)
        for offset in 1...60 {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            if candidate < firstActiveDay(calendar: calendar) { return nil }
            if matchesPattern(on: candidate, calendar: calendar) { return candidate }
        }
        return nil
    }

    /// Upcoming reminder fire dates, skipping occurrences that are already finished.
    func nextReminderDates(limit: Int, from now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        guard reminderEnabled, !isArchived, limit > 0 else { return [] }

        var results: [Date] = []
        let today = calendar.startOfDay(for: now)

        for offset in 0..<60 {
            guard results.count < limit else { break }
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { break }
            guard isScheduled(on: day, calendar: calendar), !isCompleted(on: day, calendar: calendar) else { continue }
            guard let fire = calendar.date(
                bySettingHour: reminderMinutes / 60,
                minute: reminderMinutes % 60,
                second: 0,
                of: day
            ) else { continue }
            if fire > now { results.append(fire) }
        }
        return results
    }
}
