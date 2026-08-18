//
//  QuestEngine.swift
//  Taskly
//

import Foundation
import SwiftData

/// What happened when a quest was cleared, used to drive the celebration UI.
struct CompletionOutcome {
    var xpGained: Int
    var coinsGained: Int
    var streakBonus: Int
    var perfectDayBonus: Int
    var newStreak: Int
    var levelBefore: Int
    var levelAfter: Int
    var isPerfectDay: Bool

    var didLevelUp: Bool { levelAfter > levelBefore }
}

/// All the rules for clearing quests, awarding XP and keeping streaks honest.
///
/// Streaks are always recomputed from the stored `CompletionRecord` history rather than
/// incremented in place, so undoing a completion can never leave them drifting.
@MainActor
enum QuestEngine {
    static let perfectDayBonus = 40
    /// A clean sweep only counts once the day has a meaningful number of quests on it,
    /// otherwise clearing a single trivial task would pay out the full bonus.
    static let perfectDayMinimumQuests = 3
    /// Streak bonus caps out at +50% of base XP.
    static let maxStreakMultiplier = 0.5
    static let streakMultiplierStep = 0.02

    // MARK: - XP maths

    static func streakBonus(base: Int, streak: Int) -> Int {
        let extraDays = max(0, streak - 1)
        let multiplier = min(maxStreakMultiplier, Double(extraDays) * streakMultiplierStep)
        return Int((Double(base) * multiplier).rounded())
    }

    /// XP the player would earn for clearing this quest right now, shown on the card.
    static func projectedXP(for task: TaskItem, profile: PlayerProfile? = nil) -> Int {
        let base = baseXP(for: task, profile: profile)
        return base + streakBonus(base: base, streak: task.currentStreak + 1)
    }

    /// Mythic pays at least enough XP to finish the current level; everything else uses its table value.
    static func baseXP(for task: TaskItem, profile: PlayerProfile? = nil) -> Int {
        guard task.difficulty == .mythic else { return task.difficulty.baseXP }
        guard let profile else { return task.difficulty.baseXP }
        let remaining = max(1, profile.xpForNextLevel - profile.xpIntoLevel)
        return max(task.difficulty.baseXP, remaining)
    }

    // MARK: - Completion

    @discardableResult
    static func complete(
        _ task: TaskItem,
        profile: PlayerProfile,
        allTasks: [TaskItem],
        context: ModelContext,
        on date: Date = Date()
    ) -> CompletionOutcome? {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)

        // Turning a skip into a real clear just replaces the excuse record.
        if let existing = task.completion(on: day, calendar: calendar) {
            guard existing.wasSkipped else { return nil }
            task.completions.removeAll { $0.id == existing.id }
            context.delete(existing)
        } else if task.isCompleted(on: day, calendar: calendar) {
            return nil
        }

        let levelBefore = profile.level
        let base = baseXP(for: task, profile: profile)

        let record = CompletionRecord(timestamp: date, xpAwarded: base, category: task.category, task: task)
        context.insert(record)
        task.completions.append(record)
        task.lastCompletedDay = day
        task.totalCompletions += 1

        recomputeStreak(for: task, on: day, profile: profile, calendar: calendar)
        let bonus = streakBonus(base: base, streak: task.currentStreak)
        record.xpAwarded = base + bonus

        // Perfect day bonus lands on the completion that clears the final quest of the day.
        var perfectBonus = 0
        let perfect = isPerfectDay(allTasks: allTasks, on: day, calendar: calendar)
        if perfect, !calendar.isDate(profile.lastPerfectDay ?? .distantPast, inSameDayAs: day) {
            perfectBonus = perfectDayBonus
            profile.lastPerfectDay = day
            profile.perfectDays += 1
        }

        let gained = record.xpAwarded + perfectBonus
        profile.totalXP += gained

        let coins = Economy.coinsForQuest(xpAwarded: gained)
        record.coinsAwarded = coins
        profile.coins += coins
        profile.lifetimeCoins += coins

        recomputeDayStreak(profile: profile, allTasks: allTasks, calendar: calendar)

        return CompletionOutcome(
            xpGained: gained,
            coinsGained: coins,
            streakBonus: bonus,
            perfectDayBonus: perfectBonus,
            newStreak: task.currentStreak,
            levelBefore: levelBefore,
            levelAfter: profile.level,
            isPerfectDay: perfect
        )
    }

    /// Excuses a quest for the day: off the board, no XP, streak bridges over it.
    @discardableResult
    static func skip(
        _ task: TaskItem,
        profile: PlayerProfile,
        allTasks: [TaskItem],
        context: ModelContext,
        on date: Date = Date()
    ) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        guard !task.isCompleted(on: day, calendar: calendar) else { return false }

        let record = CompletionRecord(
            timestamp: date,
            xpAwarded: 0,
            category: task.category,
            task: task,
            wasSkipped: true
        )
        context.insert(record)
        task.completions.append(record)

        recomputeStreak(for: task, on: day, profile: profile, calendar: calendar)
        recomputeDayStreak(profile: profile, allTasks: allTasks, calendar: calendar)
        return true
    }

    static func undoCompletion(
        _ task: TaskItem,
        profile: PlayerProfile,
        allTasks: [TaskItem],
        context: ModelContext,
        on date: Date = Date()
    ) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        guard let record = task.completion(on: day, calendar: calendar) else { return }

        if !record.wasSkipped {
            profile.totalXP = max(0, profile.totalXP - record.xpAwarded)

            // Coins already spent on a reward cannot be clawed back, so the balance floors at zero
            // while the lifetime tally is corrected in full.
            profile.coins = max(0, profile.coins - record.coinsAwarded)
            profile.lifetimeCoins = max(0, profile.lifetimeCoins - record.coinsAwarded)

            // Hand back the perfect day bonus if this undo breaks the clean sweep.
            if calendar.isDate(profile.lastPerfectDay ?? .distantPast, inSameDayAs: day) {
                profile.totalXP = max(0, profile.totalXP - perfectDayBonus)
                profile.perfectDays = max(0, profile.perfectDays - 1)
                profile.lastPerfectDay = nil
            }

            task.totalCompletions = max(0, task.totalCompletions - 1)
        }

        task.completions.removeAll { $0.id == record.id }
        context.delete(record)
        task.lastCompletedDay = task.completions.filter { !$0.wasSkipped }.map(\.day).max()

        recomputeStreak(for: task, on: day, profile: profile, calendar: calendar)
        recomputeDayStreak(profile: profile, allTasks: allTasks, calendar: calendar)
    }

    // MARK: - Streaks

    /// Walks backwards through the days this quest was expected on, counting unbroken clears.
    /// Break days and skips are bridged so they do not wipe the streak.
    static func recomputeStreak(
        for task: TaskItem,
        on referenceDay: Date,
        profile: PlayerProfile? = nil,
        calendar: Calendar = .current
    ) {
        var streak = 0
        var cursor: Date? = calendar.startOfDay(for: referenceDay)

        // Open, skipped, or break days at the tip don't count — step back to the last clear.
        if let day = cursor, shouldBridge(day, task: task, profile: profile, calendar: calendar)
            || !task.isCleared(on: day, calendar: calendar) {
            cursor = previousCountableDay(before: day, task: task, profile: profile, calendar: calendar)
        }

        while let day = cursor {
            if shouldBridge(day, task: task, profile: profile, calendar: calendar) {
                cursor = previousCountableDay(before: day, task: task, profile: profile, calendar: calendar)
                continue
            }
            guard task.isCleared(on: day, calendar: calendar) else { break }
            streak += 1
            cursor = previousCountableDay(before: day, task: task, profile: profile, calendar: calendar)
        }

        task.currentStreak = streak
        task.bestStreak = max(task.bestStreak, streak)
    }

    private static func shouldBridge(
        _ day: Date,
        task: TaskItem,
        profile: PlayerProfile?,
        calendar: Calendar
    ) -> Bool {
        profile?.isOnBreak(on: day, calendar: calendar) == true
            || task.isSkipped(on: day, calendar: calendar)
    }

    /// Previous scheduled day that still counts toward a streak (not a break or skip).
    private static func previousCountableDay(
        before day: Date,
        task: TaskItem,
        profile: PlayerProfile?,
        calendar: Calendar
    ) -> Date? {
        var cursor = task.previousScheduledDay(before: day, calendar: calendar)
        while let candidate = cursor, shouldBridge(candidate, task: task, profile: profile, calendar: calendar) {
            cursor = task.previousScheduledDay(before: candidate, calendar: calendar)
        }
        return cursor
    }

    /// A day counts toward the player streak if at least one quest was cleared on it.
    /// Break days bridge the gap so a vacation does not reset the day streak.
    static func recomputeDayStreak(profile: PlayerProfile, allTasks: [TaskItem], calendar: Calendar = .current) {
        let activeDays = Set(
            allTasks
                .flatMap(\.completions)
                .filter { !$0.wasSkipped }
                .map { calendar.startOfDay(for: $0.day) }
        )
        let today = calendar.startOfDay(for: Date())

        var cursor = today
        if !activeDays.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                profile.currentDayStreak = 0
                return
            }
            cursor = yesterday
        }

        // Walk back past a leading run of break days with no activity.
        while profile.isOnBreak(on: cursor, calendar: calendar), !activeDays.contains(cursor) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        var streak = 0
        while true {
            if profile.isOnBreak(on: cursor, calendar: calendar) {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
                continue
            }
            guard activeDays.contains(cursor) else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        profile.currentDayStreak = streak
        profile.bestDayStreak = max(profile.bestDayStreak, streak)
        profile.lastActiveDay = activeDays.max()
    }

    // MARK: - Day queries

    static func tasks(_ tasks: [TaskItem], scheduledOn day: Date, calendar: Calendar = .current) -> [TaskItem] {
        tasks.filter { $0.isScheduled(on: day, calendar: calendar) }
    }

    static func isPerfectDay(allTasks: [TaskItem], on day: Date, calendar: Calendar = .current) -> Bool {
        let scheduled = tasks(allTasks, scheduledOn: day, calendar: calendar)
        guard scheduled.count >= perfectDayMinimumQuests else { return false }
        // Skips don't count — a perfect day means everything was actually cleared.
        return scheduled.allSatisfy { $0.isCleared(on: day, calendar: calendar) }
    }

    /// Whether every quest on the day is done, regardless of how many there were.
    /// Used for the "board cleared" banner, which should show even on light days.
    static func isBoardClear(allTasks: [TaskItem], on day: Date, calendar: Calendar = .current) -> Bool {
        let scheduled = tasks(allTasks, scheduledOn: day, calendar: calendar)
        guard !scheduled.isEmpty else { return false }
        return scheduled.allSatisfy { $0.isCompleted(on: day, calendar: calendar) }
    }

    /// Total XP still sitting on the board for a given day.
    static func remainingXP(
        allTasks: [TaskItem],
        on day: Date,
        profile: PlayerProfile? = nil,
        calendar: Calendar = .current
    ) -> Int {
        tasks(allTasks, scheduledOn: day, calendar: calendar)
            .filter { !$0.isCompleted(on: day, calendar: calendar) }
            .reduce(0) { $0 + projectedXP(for: $1, profile: profile) }
    }
}
