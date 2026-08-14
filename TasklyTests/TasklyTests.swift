//
//  TasklyTests.swift
//  TasklyTests
//
//  Created by Ryan Gupta on 7/28/26.
//

import Testing
import Foundation
import SwiftData
@testable import Taskly

// MARK: - Level curve

struct BoardOrderTests {
    @Test func movingAnItemUpdatesThePendingOrder() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let next = BoardOrder.moving(a, onto: c, in: [a, b, c])
        #expect(next == [b, c, a])
    }

    @Test func applyRewritesSortIndexesAroundNonPendingTasks() {
        let pendingA = TaskItem(title: "A", sortIndex: 0)
        let other = TaskItem(title: "Other", sortIndex: 1)
        let pendingB = TaskItem(title: "B", sortIndex: 2)
        // Force stable IDs for the assertion by using the live objects.
        BoardOrder.apply(
            pendingOrder: [pendingB.id, pendingA.id],
            to: [pendingA, other, pendingB]
        )

        #expect(pendingB.sortIndex == 0)
        #expect(other.sortIndex == 1)
        #expect(pendingA.sortIndex == 2)
    }
}

struct DifficultyTests {
    @Test func ultraPaysMoreThanEpicAndTakesSixPips() {
        #expect(TaskDifficulty.ultra.baseXP > TaskDifficulty.epic.baseXP)
        #expect(TaskDifficulty.ultra.baseXP == 120)
        #expect(TaskDifficulty.ultra.pips == TaskDifficulty.maxPips)
        #expect(TaskDifficulty.ultra.blurb.lowercased().contains("day"))
    }
}

struct LevelSystemTests {

    @Test func levelOneStartsAtZeroXP() {
        #expect(LevelSystem.cumulativeXP(forLevel: 1) == 0)
        #expect(LevelSystem.level(forXP: 0) == 1)
        #expect(LevelSystem.level(forXP: 99) == 1)
    }

    @Test func firstLevelCosts100XP() {
        #expect(LevelSystem.xpToAdvance(fromLevel: 1) == 100)
        #expect(LevelSystem.level(forXP: 100) == 2)
    }

    @Test func eachLevelCostsMoreThanTheLast() {
        for level in 1..<40 {
            #expect(LevelSystem.xpToAdvance(fromLevel: level) < LevelSystem.xpToAdvance(fromLevel: level + 1))
        }
    }

    /// The closed form cumulative total must match summing the per-level costs.
    @Test func cumulativeMatchesTheSumOfCosts() {
        var running = 0
        for level in 1...50 {
            #expect(LevelSystem.cumulativeXP(forLevel: level) == running)
            running += LevelSystem.xpToAdvance(fromLevel: level)
        }
    }

    @Test func levelLookupIsConsistentWithThresholds() {
        for level in 1...30 {
            let threshold = LevelSystem.cumulativeXP(forLevel: level)
            #expect(LevelSystem.level(forXP: threshold) == level)
            if level > 1 {
                #expect(LevelSystem.level(forXP: threshold - 1) == level - 1)
            }
        }
    }

    @Test func ranksAdvanceWithLevel() {
        #expect(Rank.forLevel(1) == .novice)
        #expect(Rank.forLevel(5) == .apprentice)
        #expect(Rank.forLevel(24) == .master)
        #expect(Rank.forLevel(999) == .legend)
    }
}

// MARK: - Scheduling

struct SchedulingTests {
    private let calendar = Calendar.current

    @Test func dailyQuestsAreScheduledEveryDay() {
        let task = TaskItem(title: "Brush my teeth", recurrence: .daily)
        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: Date())!
            #expect(task.isScheduled(on: day))
        }
    }

    @Test func weeklyQuestsOnlyLandOnSelectedDays() {
        // Monday and Wednesday only.
        let mask = (1 << 1) | (1 << 3)
        let task = TaskItem(title: "Workout", recurrence: .weekly, weekdayMask: mask)

        for offset in 0..<14 {
            let day = calendar.date(byAdding: .day, value: offset, to: Date())!
            let weekdayIndex = calendar.component(.weekday, from: day) - 1
            let expected = weekdayIndex == 1 || weekdayIndex == 3
            #expect(task.isScheduled(on: day) == expected)
        }
    }

    @Test func questsDoNotAppearBeforeTheyWereCreated() {
        let task = TaskItem(title: "Study math", recurrence: .daily)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        #expect(!task.isScheduled(on: yesterday))
    }

    @Test func archivedQuestsAreNeverScheduled() {
        let task = TaskItem(title: "Old habit", recurrence: .daily)
        task.isArchived = true
        #expect(!task.isScheduled(on: Date()))
    }

    @Test func questQueuedForTomorrowStaysOffTodaysBoard() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let task = TaskItem(title: "Study USACO", recurrence: .daily, startDay: tomorrow)

        #expect(!task.isScheduled(on: Date()))
        #expect(task.isScheduled(on: tomorrow))
        #expect(task.isQueuedForLater)
        #expect(task.startDayLabel == "Tomorrow")
    }

    @Test func oneOffQueuedForTomorrowOnlyAppearsFromThatDay() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let task = TaskItem(title: "Text my friend", recurrence: .once, startDay: tomorrow)

        #expect(!task.isScheduled(on: Date()))
        #expect(task.isScheduled(on: tomorrow))
        #expect(!task.isOverdue)
    }

    @Test func weeklyQuestQueuedLaterStillRespectsItsWeekdays() {
        let start = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: Date()))!
        let weekdayIndex = calendar.component(.weekday, from: start) - 1
        let task = TaskItem(
            title: "Work on app",
            recurrence: .weekly,
            weekdayMask: 1 << weekdayIndex,
            startDay: start
        )

        #expect(task.isScheduled(on: start))
        // Same weekday a week earlier falls before the start day.
        let weekBefore = calendar.date(byAdding: .day, value: -7, to: start)!
        #expect(!task.isScheduled(on: weekBefore))
    }

    @Test func remindersDoNotFireBeforeTheStartDay() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let task = TaskItem(
            title: "Make my bed",
            recurrence: .daily,
            reminderEnabled: true,
            reminderMinutes: 8 * 60,
            startDay: tomorrow
        )

        let fires = task.nextReminderDates(limit: 3, from: calendar.startOfDay(for: Date()))
        #expect(!fires.isEmpty)
        #expect(fires.allSatisfy { $0 >= calendar.startOfDay(for: tomorrow) })
    }

    @Test func streaksDoNotLookBackPastTheStartDay() {
        let start = calendar.startOfDay(for: Date())
        let task = TaskItem(title: "Study math", recurrence: .daily, startDay: start)
        #expect(task.previousScheduledDay(before: start) == nil)
    }

    @Test func questWithoutAStartDayFallsBackToItsCreationDay() {
        let task = TaskItem(title: "Legacy quest", recurrence: .daily)
        #expect(task.startDay == nil)
        #expect(task.firstActiveDay() == calendar.startOfDay(for: task.createdAt))
        #expect(!task.isQueuedForLater)
        #expect(task.startDayLabel == nil)
    }

    @Test func weekdaySummaryUsesFriendlyNames() {
        #expect(Weekdays.summary(for: Weekdays.all) == "Every day")
        #expect(Weekdays.summary(for: Weekdays.weekdaysOnly) == "Weekdays")
        #expect(Weekdays.summary(for: Weekdays.weekendsOnly) == "Weekends")
        #expect(Weekdays.summary(for: 0) == "No days")
    }
}

// MARK: - XP and streaks

@MainActor
struct QuestEngineTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            TaskItem.self,
            CompletionRecord.self,
            PlayerProfile.self,
            FocusSession.self,
            Reward.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    @Test func completingAQuestAwardsItsBaseXP() throws {
        let context = try makeContext()
        let profile = PlayerProfile()
        let task = TaskItem(title: "Study USACO", difficulty: .hard)
        context.insert(profile)
        context.insert(task)

        let outcome = QuestEngine.complete(task, profile: profile, allTasks: [task], context: context)

        #expect(outcome?.xpGained == TaskDifficulty.hard.baseXP)
        #expect(profile.totalXP == TaskDifficulty.hard.baseXP)
        #expect(task.totalCompletions == 1)
        #expect(task.isCompleted(on: Date()))
    }

    @Test func completingTwiceInADayIsIgnored() throws {
        let context = try makeContext()
        let profile = PlayerProfile()
        let task = TaskItem(title: "Make my bed", difficulty: .trivial)
        context.insert(profile)
        context.insert(task)

        QuestEngine.complete(task, profile: profile, allTasks: [task], context: context)
        let second = QuestEngine.complete(task, profile: profile, allTasks: [task], context: context)

        #expect(second == nil)
        #expect(profile.totalXP == TaskDifficulty.trivial.baseXP)
        #expect(task.totalCompletions == 1)
    }

    @Test func undoingACompletionRestoresTheOriginalState() throws {
        let context = try makeContext()
        let profile = PlayerProfile()
        let task = TaskItem(title: "Text a friend", difficulty: .easy)
        context.insert(profile)
        context.insert(task)

        QuestEngine.complete(task, profile: profile, allTasks: [task], context: context)
        QuestEngine.undoCompletion(task, profile: profile, allTasks: [task], context: context)

        #expect(profile.totalXP == 0)
        #expect(task.totalCompletions == 0)
        #expect(task.currentStreak == 0)
        #expect(!task.isCompleted(on: Date()))
    }

    @Test func xpNeverGoesNegative() throws {
        let context = try makeContext()
        let profile = PlayerProfile()
        let task = TaskItem(title: "Journal", difficulty: .normal)
        context.insert(profile)
        context.insert(task)

        QuestEngine.complete(task, profile: profile, allTasks: [task], context: context)
        profile.totalXP = 5 // Simulate drift from an earlier reset.
        QuestEngine.undoCompletion(task, profile: profile, allTasks: [task], context: context)

        #expect(profile.totalXP == 0)
    }

    @Test func streakBonusGrowsButIsCapped() {
        let base = 100
        #expect(QuestEngine.streakBonus(base: base, streak: 1) == 0)
        #expect(QuestEngine.streakBonus(base: base, streak: 6) == 10)
        // 50% ceiling, reached at a 26 day streak and held afterwards.
        #expect(QuestEngine.streakBonus(base: base, streak: 26) == 50)
        #expect(QuestEngine.streakBonus(base: base, streak: 500) == 50)
    }

    /// A single trivial quest should not pay out the full clean-sweep bonus.
    @Test func perfectDayNeedsAMeaningfulBoard() throws {
        let context = try makeContext()
        let profile = PlayerProfile()
        let task = TaskItem(title: "Make my bed", difficulty: .trivial)
        context.insert(profile)
        context.insert(task)

        let outcome = QuestEngine.complete(task, profile: profile, allTasks: [task], context: context)

        #expect(outcome?.perfectDayBonus == 0)
        #expect(profile.perfectDays == 0)
        #expect(QuestEngine.isBoardClear(allTasks: [task], on: Date()))
    }

    @Test func clearingAFullBoardPaysThePerfectDayBonus() throws {
        let context = try makeContext()
        let profile = PlayerProfile()
        let tasks = (0..<3).map { TaskItem(title: "Quest \($0)", difficulty: .easy) }
        context.insert(profile)
        tasks.forEach(context.insert)

        var outcomes: [CompletionOutcome] = []
        for task in tasks {
            if let outcome = QuestEngine.complete(task, profile: profile, allTasks: tasks, context: context) {
                outcomes.append(outcome)
            }
        }

        #expect(outcomes.count == 3)
        #expect(outcomes.last?.perfectDayBonus == QuestEngine.perfectDayBonus)
        #expect(profile.perfectDays == 1)
        // Three easy quests plus the bonus.
        #expect(profile.totalXP == TaskDifficulty.easy.baseXP * 3 + QuestEngine.perfectDayBonus)
    }

    @Test func undoingAClearBoardTakesTheBonusBack() throws {
        let context = try makeContext()
        let profile = PlayerProfile()
        let tasks = (0..<3).map { TaskItem(title: "Quest \($0)", difficulty: .easy) }
        context.insert(profile)
        tasks.forEach(context.insert)

        for task in tasks {
            QuestEngine.complete(task, profile: profile, allTasks: tasks, context: context)
        }
        QuestEngine.undoCompletion(tasks[0], profile: profile, allTasks: tasks, context: context)

        #expect(profile.perfectDays == 0)
        #expect(profile.totalXP == TaskDifficulty.easy.baseXP * 2)
    }

    @Test func dayStreakCountsConsecutiveActiveDays() throws {
        let context = try makeContext()
        let calendar = Calendar.current
        let profile = PlayerProfile()
        let task = TaskItem(title: "Study math", difficulty: .normal)
        context.insert(profile)
        context.insert(task)

        // Backdate two clears so today makes three days in a row.
        for offset in [2, 1] {
            let day = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let record = CompletionRecord(timestamp: day, xpAwarded: 20, category: .study, task: task)
            context.insert(record)
            task.completions.append(record)
        }

        QuestEngine.complete(task, profile: profile, allTasks: [task], context: context)

        #expect(profile.currentDayStreak == 3)
        #expect(profile.bestDayStreak == 3)
    }

    @Test func aBreakBridgesTheDayStreak() throws {
        let context = try makeContext()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let profile = PlayerProfile()
        let task = TaskItem(title: "Study math", difficulty: .normal)
        context.insert(profile)
        context.insert(task)

        // Active two days ago, then a one-day break yesterday with no clears.
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let record = CompletionRecord(timestamp: twoDaysAgo, xpAwarded: 20, category: .study, task: task)
        context.insert(record)
        task.completions.append(record)

        profile.setBreak(from: yesterday, to: yesterday)
        QuestEngine.complete(task, profile: profile, allTasks: [task], context: context)

        #expect(profile.currentDayStreak == 2)
    }

    @Test func skippingExcusesAQuestWithoutPayingXP() throws {
        let context = try makeContext()
        let profile = PlayerProfile()
        let task = TaskItem(title: "Workout", difficulty: .hard)
        context.insert(profile)
        context.insert(task)

        #expect(QuestEngine.skip(task, profile: profile, allTasks: [task], context: context))
        #expect(task.isSkipped(on: Date()))
        #expect(!task.isCleared(on: Date()))
        #expect(profile.totalXP == 0)
        #expect(task.totalCompletions == 0)
        #expect(task.currentStreak == 0)
    }

    @Test func aSkipBridgesTheQuestStreak() throws {
        let context = try makeContext()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let profile = PlayerProfile()
        let start = calendar.date(byAdding: .day, value: -7, to: today)!
        let task = TaskItem(
            title: "Study math",
            difficulty: .normal,
            recurrence: .daily,
            startDay: start
        )
        context.insert(profile)
        context.insert(task)

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let record = CompletionRecord(timestamp: yesterday, xpAwarded: 20, category: .study, task: task)
        context.insert(record)
        task.completions.append(record)
        task.lastCompletedDay = yesterday
        task.totalCompletions = 1

        #expect(QuestEngine.skip(task, profile: profile, allTasks: [task], context: context, on: today))
        #expect(task.currentStreak == 1)
    }
}

// MARK: - Breaks

struct BreakTests {
    private let calendar = Calendar.current

    @Test func breakCoversInclusiveDateRange() {
        let profile = PlayerProfile()
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 3, to: start)!
        profile.setBreak(from: start, to: end)

        #expect(profile.isOnBreak(on: start))
        #expect(profile.isOnBreak(on: end))
        #expect(profile.isOnBreak(on: calendar.date(byAdding: .day, value: 1, to: start)!))
        #expect(!profile.isOnBreak(on: calendar.date(byAdding: .day, value: -1, to: start)!))
        #expect(!profile.isOnBreak(on: calendar.date(byAdding: .day, value: 4, to: start)!))
    }

    @Test func clearingABreakRemovesIt() {
        let profile = PlayerProfile()
        profile.setBreak(from: Date(), to: Date())
        #expect(profile.hasBreakScheduled)
        profile.clearBreak()
        #expect(!profile.hasBreakScheduled)
        #expect(!profile.isOnBreak())
    }
}

// MARK: - Notifications

@MainActor
struct NotificationPlanTests {

    @Test func remindersSkipQuestsAlreadyCleared() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Counted from midnight, so today's late occurrence is ahead of "now" no matter
        // what time the suite actually runs.
        let task = TaskItem(title: "Brush my teeth", reminderEnabled: true, reminderMinutes: 23 * 60 + 55)

        #expect(task.nextReminderDates(limit: 3, from: today).contains { calendar.isDate($0, inSameDayAs: today) })

        task.lastCompletedDay = today
        let record = CompletionRecord(xpAwarded: 5, category: .routine, task: task)
        task.completions.append(record)

        let after = task.nextReminderDates(limit: 3, from: today)
        #expect(!after.contains { calendar.isDate($0, inSameDayAs: today) })
        #expect(after.count == 3, "The queue should backfill with later days")
    }

    @Test func questsWithoutRemindersProduceNoFireDates() {
        let task = TaskItem(title: "Read", reminderEnabled: false)
        #expect(task.nextReminderDates(limit: 3).isEmpty)
    }

    @Test func planIsEmptyWhenNotificationsAreOff() {
        let profile = PlayerProfile()
        profile.notificationsEnabled = false
        let task = TaskItem(title: "Study USACO", reminderEnabled: true)

        let plan = NotificationManager.shared.buildPlan(tasks: [task], profile: profile)
        #expect(plan.isEmpty)
    }

    @Test func planIncludesRemindersAndDigestsInChronologicalOrder() {
        let profile = PlayerProfile()
        profile.notificationsEnabled = true
        let task = TaskItem(title: "Work on my app", reminderEnabled: true, reminderMinutes: 12 * 60)

        let plan = NotificationManager.shared.buildPlan(tasks: [task], profile: profile)

        #expect(!plan.isEmpty)
        #expect(plan.contains { $0.kind == .questReminder })
        #expect(plan.contains { $0.kind == .eveningNudge })
        #expect(plan == plan.sorted { $0.fireDate < $1.fireDate })
        // Every request needs a unique identifier or later ones overwrite earlier ones.
        #expect(Set(plan.map(\.id)).count == plan.count)
    }

    @Test func eveningNudgeNamesTheUnfinishedQuests() {
        let profile = PlayerProfile()
        profile.notificationsEnabled = true
        profile.morningBriefingEnabled = false
        profile.eveningNudgeMinutes = 23 * 60 + 59
        let task = TaskItem(title: "Study USACO", difficulty: .hard)

        let plan = NotificationManager.shared.buildPlan(
            tasks: [task],
            profile: profile,
            now: Calendar.current.startOfDay(for: Date())
        )
        let nudge = plan.first { $0.kind == .eveningNudge }

        #expect(nudge?.body.contains("Study USACO") == true)
    }

    // MARK: - Encouragement pings

    private let calendar = Calendar.current

    /// A far future expiry keeps the signing alerts out of these plans.
    private var quietExpiry: BuildExpiry {
        BuildExpiry(expiresAt: Date().addingTimeInterval(365 * 86_400), source: .provisioningProfile)
    }

    @Test func encouragementPingsFillTheMiddleOfTheDay() {
        let profile = PlayerProfile()
        let task = TaskItem(title: "Study math", recurrence: .daily)
        let midnight = calendar.startOfDay(for: Date())

        let plan = NotificationManager.shared.buildPlan(
            tasks: [task],
            profile: profile,
            now: midnight,
            buildExpiry: quietExpiry
        )
        let pings = plan.filter { $0.kind == .encouragement }

        // Three a day by default, for today and tomorrow.
        #expect(pings.count == profile.encouragementPingsPerDay * 2)
        for ping in pings {
            let minutes = PlayerProfile.minutes(from: ping.fireDate)
            #expect(minutes > profile.morningBriefingMinutes)
            #expect(minutes < profile.eveningNudgeMinutes)
        }
    }

    @Test func encouragementCadenceFollowsThePreference() {
        let profile = PlayerProfile()
        profile.encouragementPingsPerDay = 5
        let task = TaskItem(title: "Work on app", recurrence: .daily)

        let plan = NotificationManager.shared.buildPlan(
            tasks: [task],
            profile: profile,
            now: calendar.startOfDay(for: Date()),
            buildExpiry: quietExpiry
        )

        #expect(plan.filter { $0.kind == .encouragement }.count == 10)
    }

    @Test func aClearedBoardStopsBeingCheeredAt() {
        let profile = PlayerProfile()
        let task = TaskItem(title: "Make my bed", recurrence: .daily)
        let today = calendar.startOfDay(for: Date())
        task.lastCompletedDay = today
        task.completions.append(CompletionRecord(xpAwarded: 5, category: .routine, task: task))

        let plan = NotificationManager.shared.buildPlan(
            tasks: [task],
            profile: profile,
            now: today,
            buildExpiry: quietExpiry
        )
        let todayPings = plan.filter {
            $0.kind == .encouragement && calendar.isDate($0.fireDate, inSameDayAs: today)
        }

        #expect(todayPings.isEmpty, "Nothing left to do means nothing left to nag about")
        // Tomorrow's board is untouched, so those pings survive.
        #expect(plan.contains { $0.kind == .encouragement })
    }

    @Test func encouragementCanBeSwitchedOff() {
        let profile = PlayerProfile()
        profile.encouragementEnabled = false
        let task = TaskItem(title: "Study USACO", recurrence: .daily)

        let plan = NotificationManager.shared.buildPlan(
            tasks: [task],
            profile: profile,
            now: calendar.startOfDay(for: Date()),
            buildExpiry: quietExpiry
        )

        #expect(!plan.contains { $0.kind == .encouragement })
    }

    @Test func aBreakSilencesQuestPingsButKeepsBuildExpiry() {
        let profile = PlayerProfile()
        let today = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 2, to: today)!
        profile.setBreak(from: today, to: end)
        let task = TaskItem(title: "Study math", reminderEnabled: true, reminderMinutes: 12 * 60)
        let expiry = BuildExpiry(
            expiresAt: calendar.date(byAdding: .day, value: 1, to: today)!.addingTimeInterval(12 * 3600),
            source: .provisioningProfile
        )

        let plan = NotificationManager.shared.buildPlan(
            tasks: [task],
            profile: profile,
            now: today,
            buildExpiry: expiry
        )

        #expect(
            !plan.contains { $0.kind != .buildExpiry && profile.isOnBreak(on: $0.fireDate) },
            "Quest pings should stay quiet on break days"
        )
        #expect(plan.contains { $0.kind == .buildExpiry })
    }

    // MARK: - Build expiry

    @Test func buildExpiryWarnsThreeTimesBeforeTheSignatureDies() {
        let profile = PlayerProfile()
        let now = calendar.startOfDay(for: Date())
        let expiresAt = calendar.date(byAdding: .day, value: 3, to: now)!.addingTimeInterval(12 * 3600)
        let expiry = BuildExpiry(expiresAt: expiresAt, source: .provisioningProfile)

        let alerts = NotificationManager.shared
            .buildPlan(tasks: [], profile: profile, now: now, buildExpiry: expiry)
            .filter { $0.kind == .buildExpiry }

        #expect(alerts.count == 3, "Two days out, one day out and on the day itself")
        #expect(alerts.allSatisfy { $0.fireDate < expiresAt })
        #expect(alerts.last?.title.contains("today") == true)
        #expect(alerts.last?.body.contains("Xcode") == true)
    }

    @Test func aLongLivedProfileDoesNotNag() {
        let profile = PlayerProfile()
        let now = Date()
        let expiry = BuildExpiry(
            expiresAt: calendar.date(byAdding: .day, value: 200, to: now)!,
            source: .provisioningProfile
        )

        let plan = NotificationManager.shared
            .buildPlan(tasks: [], profile: profile, now: now, buildExpiry: expiry)

        #expect(!plan.contains { $0.kind == .buildExpiry })
    }

    @Test func anExpiredBuildHasNothingLeftToWarnAbout() {
        let profile = PlayerProfile()
        let now = Date()
        let expiry = BuildExpiry(expiresAt: now.addingTimeInterval(-3600), source: .buildDateEstimate)

        let plan = NotificationManager.shared
            .buildPlan(tasks: [], profile: profile, now: now, buildExpiry: expiry)

        #expect(!plan.contains { $0.kind == .buildExpiry })
    }

    @Test func buildExpiryAlertsCanBeSwitchedOff() {
        let profile = PlayerProfile()
        profile.buildExpiryAlertsEnabled = false
        let now = calendar.startOfDay(for: Date())
        let expiry = BuildExpiry(
            expiresAt: calendar.date(byAdding: .day, value: 2, to: now)!,
            source: .provisioningProfile
        )

        let plan = NotificationManager.shared
            .buildPlan(tasks: [], profile: profile, now: now, buildExpiry: expiry)

        #expect(!plan.contains { $0.kind == .buildExpiry })
    }
}

// MARK: - Encouragement copy

struct EncouragementTests {
    @Test func copyReflectsHowFarAlongTheDayIs() {
        let untouched = Encouragement.message(
            done: 0, total: 4, remainingTitles: ["A", "B", "C", "D"], xp: 20, streak: 0, seed: 0
        )
        #expect(untouched.body.contains("4 quests waiting"))

        let midway = Encouragement.message(
            done: 2, total: 5, remainingTitles: ["C", "D", "E"], xp: 15, streak: 0, seed: 1
        )
        #expect(midway.body.contains("2 of 5 cleared"))
    }

    @Test func theFinalQuestIsCalledOutByName() {
        let message = Encouragement.message(
            done: 3, total: 4, remainingTitles: ["Study USACO"], xp: 10, streak: 0, seed: 2
        )
        #expect(message.body.contains("Study USACO"))
    }

    @Test func aLiveStreakIsMentionedWhileTheBoardIsUntouched() {
        let message = Encouragement.message(
            done: 0, total: 3, remainingTitles: [], xp: 15, streak: 5, seed: 0
        )
        #expect(message.body.contains("5 day streak"))
    }

    @Test func consecutivePingsUseDifferentLines() {
        let titles = (0..<3).map {
            Encouragement.message(done: 0, total: 3, remainingTitles: [], xp: 10, streak: 0, seed: $0).title
        }
        #expect(Set(titles).count == 3, "Three identical pings in one day would read as a bug")
    }
}

// MARK: - Build expiry

struct BuildExpiryTests {
    private let calendar = Calendar.current

    @Test func daysRemainingCountsWholeDays() {
        let now = calendar.startOfDay(for: Date())
        let expiry = BuildExpiry(
            expiresAt: calendar.date(byAdding: .day, value: 7, to: now)!,
            source: .provisioningProfile
        )

        #expect(expiry.daysRemaining(from: now) == 7)
        #expect(!expiry.isExpired(at: now))
    }

    @Test func anExpiryLaterTodayStillReadsAsZeroDaysLeft() {
        // Anchored mid morning so the hour it adds cannot roll into tomorrow.
        let now = calendar.startOfDay(for: Date()).addingTimeInterval(9 * 3600)
        let expiry = BuildExpiry(expiresAt: now.addingTimeInterval(3600), source: .buildDateEstimate)

        #expect(expiry.daysRemaining(from: now) == 0)
        #expect(!expiry.isExpired(at: now))
    }

    @Test func aPastExpiryReadsAsExpired() {
        let expiry = BuildExpiry(expiresAt: Date().addingTimeInterval(-60), source: .buildDateEstimate)
        #expect(expiry.isExpired())
    }
}

// MARK: - Economy and focus

struct EconomyTests {
    @Test func questCoinsScaleWithXPButNeverPayZero() {
        #expect(Economy.coinsForQuest(xpAwarded: 5) == 1)
        #expect(Economy.coinsForQuest(xpAwarded: 10) == 1)
        #expect(Economy.coinsForQuest(xpAwarded: 35) == 3)
    }

    @Test func focusPaysInFiveMinuteBlocks() {
        #expect(Economy.coinsForFocus(seconds: 59) == 0)
        #expect(Economy.coinsForFocus(seconds: 60) == 0)
        #expect(Economy.coinsForFocus(seconds: 5 * 60) == 1)
        #expect(Economy.coinsForFocus(seconds: 14 * 60) == 2)
        #expect(Economy.xpForFocus(seconds: 25 * 60) == 10)
    }

    @Test func secondsToNextBlockPointsAtTheNextPayout() {
        #expect(Economy.secondsToNextBlock(seconds: 0) == 5 * 60)
        #expect(Economy.secondsToNextBlock(seconds: 5 * 60) == 5 * 60)
        #expect(Economy.secondsToNextBlock(seconds: 7 * 60) == 3 * 60)
    }
}

@MainActor
struct FocusEngineTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            TaskItem.self,
            CompletionRecord.self,
            PlayerProfile.self,
            FocusSession.self,
            Reward.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    @Test func pausingBanksElapsedTimeWithoutLosingIt() {
        let controller = FocusController()
        let start = Date()
        controller.start(questID: nil, questTitle: "Study math", minutes: 25, at: start)

        let pauseAt = start.addingTimeInterval(7 * 60)
        controller.pause(at: pauseAt)
        #expect(controller.active?.isPaused == true)
        #expect(controller.active?.elapsedSeconds(at: pauseAt.addingTimeInterval(120)) == 7 * 60)

        let resumeAt = pauseAt.addingTimeInterval(120)
        controller.resume(at: resumeAt)
        let later = resumeAt.addingTimeInterval(3 * 60)
        #expect(controller.active?.elapsedSeconds(at: later) == 10 * 60)
    }

    @Test func finishingASessionBanksCoinsAndXP() throws {
        let context = try makeContext()
        let profile = PlayerProfile()
        context.insert(profile)

        let controller = FocusController()
        let start = Date()
        controller.start(questID: nil, questTitle: "Work on app", minutes: 25, at: start)
        let active = controller.takeSession()!

        let outcome = FocusEngine.finish(
            active,
            at: start.addingTimeInterval(25 * 60),
            profile: profile,
            context: context
        )

        #expect(outcome.coins == 5)
        #expect(outcome.xp == 10)
        #expect(outcome.didCompleteFullSession)
        #expect(profile.coins == 5)
        #expect(profile.focusedSecondsTotal == 25 * 60)
    }

    @Test func redeemingARewardSpendsCoinsWithoutGoingNegative() {
        let profile = PlayerProfile()
        profile.coins = 40
        let reward = Reward(title: "Episode", cost: 40)

        #expect(RewardStore.redeem(reward, profile: profile))
        #expect(profile.coins == 0)
        #expect(profile.coinsSpent == 40)
        #expect(reward.timesRedeemed == 1)

        #expect(!RewardStore.redeem(reward, profile: profile))
        #expect(profile.coins == 0)
    }
}

extension PlannedNotification: @retroactive Equatable {
    public static func == (lhs: PlannedNotification, rhs: PlannedNotification) -> Bool {
        lhs.id == rhs.id && lhs.fireDate == rhs.fireDate
    }
}
