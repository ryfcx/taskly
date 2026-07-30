//
//  PlayerProfile.swift
//  Taskly
//

import Foundation
import SwiftData

/// The single player record: XP bank, day streak and notification preferences.
@Model
final class PlayerProfile {
    var id: UUID = UUID()
    var displayName: String = "Adventurer"
    var avatarSymbol: String = "person.fill"
    var totalXP: Int = 0
    var createdAt: Date = Date()

    var currentDayStreak: Int = 0
    var bestDayStreak: Int = 0
    var lastActiveDay: Date?
    var perfectDays: Int = 0
    /// Guards against paying the clean-sweep bonus twice in one day.
    var lastPerfectDay: Date?

    var hasSeenOnboarding: Bool = false

    // Coins: the spendable balance, kept apart from XP so levels only ever climb.
    var coins: Int = 0
    var lifetimeCoins: Int = 0
    var coinsSpent: Int = 0
    var focusedSecondsTotal: Int = 0
    var defaultFocusMinutes: Int = 25

    // Notification preferences
    var notificationsEnabled: Bool = true
    var morningBriefingEnabled: Bool = true
    /// Minutes past midnight for the "here's your day" notification.
    var morningBriefingMinutes: Int = 8 * 60
    var eveningNudgeEnabled: Bool = true
    /// Minutes past midnight for the "you still have unfinished quests" notification.
    var eveningNudgeMinutes: Int = 20 * 60
    var streakAlertsEnabled: Bool = true
    /// Upbeat check-ins spread between the briefing and the evening nudge.
    var encouragementEnabled: Bool = true
    var encouragementPingsPerDay: Int = 3
    /// Warns before this build's seven day free-account signature runs out.
    var buildExpiryAlertsEnabled: Bool = true

    init() {
        self.id = UUID()
        self.createdAt = Date()
    }
}

extension PlayerProfile {
    var level: Int { LevelSystem.level(forXP: totalXP) }
    var rank: Rank { Rank.forLevel(level) }
    var xpIntoLevel: Int { totalXP - LevelSystem.cumulativeXP(forLevel: level) }
    var xpForNextLevel: Int { LevelSystem.xpToAdvance(fromLevel: level) }

    var levelProgress: Double {
        let needed = xpForNextLevel
        guard needed > 0 else { return 0 }
        return min(1, max(0, Double(xpIntoLevel) / Double(needed)))
    }

    var morningBriefingDate: Date {
        Self.date(fromMinutes: morningBriefingMinutes)
    }

    var eveningNudgeDate: Date {
        Self.date(fromMinutes: eveningNudgeMinutes)
    }

    static func date(fromMinutes minutes: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
