//
//  Economy.swift
//  Taskly
//

import Foundation

/// Coins are the spendable half of the game. XP only ever goes up because levels and ranks
/// depend on it, so rewards are bought with a separate balance that can be drained.
///
/// Two ways to earn: clearing quests pays a small cut of their XP, and focus sessions pay
/// by the minute. Focus is the better rate, which is the point of it.
enum Economy {
    /// A cleared quest pays one coin per this much XP.
    static let xpPerQuestCoin = 10
    /// Focus pays out in five minute blocks, so a part finished block earns nothing.
    static let focusBlockSeconds = 5 * 60
    static let coinsPerFocusBlock = 1
    static let xpPerFocusBlock = 2
    /// Sessions shorter than this are treated as false starts and pay nothing.
    static let minimumRewardedSeconds = 60

    static let sessionLengthChoices = [15, 25, 50]
    static let minimumSessionMinutes = 5
    static let maximumSessionMinutes = 120

    /// Coins for clearing a quest, always at least one so nothing feels unpaid.
    static func coinsForQuest(xpAwarded: Int) -> Int {
        max(1, xpAwarded / xpPerQuestCoin)
    }

    static func focusBlocks(seconds: Int) -> Int {
        guard seconds >= minimumRewardedSeconds else { return 0 }
        return seconds / focusBlockSeconds
    }

    static func coinsForFocus(seconds: Int) -> Int {
        focusBlocks(seconds: seconds) * coinsPerFocusBlock
    }

    static func xpForFocus(seconds: Int) -> Int {
        focusBlocks(seconds: seconds) * xpPerFocusBlock
    }

    /// Seconds still to run before the next block pays out, used for the "next coin in" hint.
    static func secondsToNextBlock(seconds: Int) -> Int {
        let target = max(minimumRewardedSeconds, (focusBlocks(seconds: seconds) + 1) * focusBlockSeconds)
        return max(0, target - seconds)
    }

    // MARK: - Formatting

    static func durationLabel(seconds: Int) -> String {
        let minutes = seconds / 60
        guard minutes >= 60 else { return "\(minutes)m" }
        let remainder = minutes % 60
        return remainder == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(remainder)m"
    }

    static func clockLabel(seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }
}

@MainActor
enum RewardStore {
    /// Spends the coins if there are enough. Returns false rather than allowing a debt,
    /// so the balance can never go negative.
    @discardableResult
    static func redeem(_ reward: Reward, profile: PlayerProfile, at now: Date = Date()) -> Bool {
        guard reward.isAffordable(with: profile.coins) else { return false }

        profile.coins -= reward.cost
        profile.coinsSpent += reward.cost
        reward.timesRedeemed += 1
        reward.lastRedeemedAt = now
        return true
    }
}
