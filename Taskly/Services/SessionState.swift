//
//  SessionState.swift
//  Taskly
//

import SwiftUI

struct XPToast: Identifiable, Equatable {
    let id = UUID()
    var amount: Int
    var coins: Int = 0
    var label: String
    var isBonus: Bool
}

struct LevelUpEvent: Identifiable, Equatable {
    let id = UUID()
    var newLevel: Int
    var rank: Rank
    var rankChanged: Bool
}

/// Transient, non-persisted UI state shared across the tab bar: XP toasts,
/// the level up takeover and the confetti trigger.
@MainActor
@Observable
final class SessionState {
    var xpToast: XPToast?
    var levelUpEvent: LevelUpEvent?
    var confettiTrigger = 0
    var selectedTab: AppTab = .today
    /// The day the Today tab is currently showing. New quests added from the tab bar
    /// start on this day, so planning tomorrow adds to tomorrow.
    var planningDay: Date = Calendar.current.startOfDay(for: Date())

    var isPlanningAhead: Bool {
        planningDay > Calendar.current.startOfDay(for: Date())
    }

    private var toastDismissal: Task<Void, Never>?

    func present(outcome: CompletionOutcome) {
        var label = "Quest cleared"
        if outcome.perfectDayBonus > 0 {
            label = "Perfect day! +\(outcome.perfectDayBonus) bonus"
        } else if outcome.streakBonus > 0 {
            label = "\(outcome.newStreak) day streak · +\(outcome.streakBonus) bonus"
        }

        showToast(
            XPToast(
                amount: outcome.xpGained,
                coins: outcome.coinsGained,
                label: label,
                isBonus: outcome.perfectDayBonus > 0
            )
        )

        if outcome.isPerfectDay { confettiTrigger += 1 }
        celebrate(levelBefore: outcome.levelBefore, levelAfter: outcome.levelAfter)
    }

    func present(focus outcome: FocusOutcome) {
        let focused = Economy.durationLabel(seconds: outcome.focusedSeconds)
        let label = outcome.didCompleteFullSession
            ? "Full session · \(focused) focused"
            : "\(focused) focused"

        showToast(
            XPToast(
                amount: outcome.xp,
                coins: outcome.coins,
                label: label,
                isBonus: outcome.didCompleteFullSession
            )
        )
        celebrate(levelBefore: outcome.levelBefore, levelAfter: outcome.levelAfter)
    }

    private func celebrate(levelBefore: Int, levelAfter: Int) {
        guard levelAfter > levelBefore else {
            Haptics.complete()
            return
        }

        let rank = Rank.forLevel(levelAfter)
        levelUpEvent = LevelUpEvent(
            newLevel: levelAfter,
            rank: rank,
            rankChanged: rank != Rank.forLevel(levelBefore)
        )
        Haptics.levelUp()
    }

    func showToast(_ toast: XPToast) {
        toastDismissal?.cancel()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            xpToast = toast
        }
        toastDismissal = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { xpToast = nil }
        }
    }

    func dismissLevelUp() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            levelUpEvent = nil
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case focus
    case stats
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .focus: "Focus"
        case .stats: "Stats"
        case .profile: "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .today: "bolt.fill"
        case .focus: "timer"
        case .stats: "chart.bar.fill"
        case .profile: "person.fill"
        }
    }
}
