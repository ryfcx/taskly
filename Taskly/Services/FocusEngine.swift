//
//  FocusEngine.swift
//  Taskly
//

import Foundation
import SwiftData

/// Live state for the running focus session. Elapsed time is derived from wall clock
/// stamps rather than counted by a ticking timer, so the total stays honest when the app
/// is backgrounded or the display sleeps mid session.
@MainActor
@Observable
final class FocusController {
    struct Active: Equatable {
        var questID: UUID?
        var questTitle: String
        var plannedMinutes: Int
        var startedAt: Date
        /// Everything accumulated before the current run, i.e. banked at each pause.
        var bankedSeconds: Int
        /// When the current run began, or nil while paused.
        var runningSince: Date?

        var plannedSeconds: Int { plannedMinutes * 60 }
        var isPaused: Bool { runningSince == nil }

        func elapsedSeconds(at now: Date) -> Int {
            guard let runningSince else { return bankedSeconds }
            return bankedSeconds + max(0, Int(now.timeIntervalSince(runningSince)))
        }

        func remainingSeconds(at now: Date) -> Int {
            max(0, plannedSeconds - elapsedSeconds(at: now))
        }

        func progress(at now: Date) -> Double {
            guard plannedSeconds > 0 else { return 0 }
            return min(1, Double(elapsedSeconds(at: now)) / Double(plannedSeconds))
        }

        func hasRunOut(at now: Date) -> Bool {
            elapsedSeconds(at: now) >= plannedSeconds
        }

        /// When the clock will hit zero if left alone, used to schedule the alert.
        var projectedEnd: Date? {
            guard let runningSince else { return nil }
            return runningSince.addingTimeInterval(Double(plannedSeconds - bankedSeconds))
        }
    }

    private(set) var active: Active?

    var isRunning: Bool { active?.isPaused == false }

    func start(questID: UUID?, questTitle: String, minutes: Int, at now: Date = Date()) {
        let clamped = min(max(minutes, Economy.minimumSessionMinutes), Economy.maximumSessionMinutes)
        active = Active(
            questID: questID,
            questTitle: questTitle,
            plannedMinutes: clamped,
            startedAt: now,
            bankedSeconds: 0,
            runningSince: now
        )
    }

    func pause(at now: Date = Date()) {
        guard var session = active, !session.isPaused else { return }
        session.bankedSeconds = session.elapsedSeconds(at: now)
        session.runningSince = nil
        active = session
    }

    func resume(at now: Date = Date()) {
        guard var session = active, session.isPaused else { return }
        session.runningSince = now
        active = session
    }

    /// Hands back the finished session so it can be scored, and clears the slot.
    func takeSession() -> Active? {
        defer { active = nil }
        return active
    }

    func discard() {
        active = nil
    }
}

/// What a finished session earned, used to drive the toast and level up takeover.
struct FocusOutcome: Equatable {
    var focusedSeconds: Int
    var coins: Int
    var xp: Int
    var levelBefore: Int
    var levelAfter: Int
    var questTitle: String
    var didCompleteFullSession: Bool

    var didLevelUp: Bool { levelAfter > levelBefore }
}

@MainActor
enum FocusEngine {
    /// Scores a finished session, banks the payout on the profile and logs it to history.
    static func finish(
        _ session: FocusController.Active,
        at now: Date = Date(),
        profile: PlayerProfile,
        context: ModelContext
    ) -> FocusOutcome {
        let focused = session.elapsedSeconds(at: now)
        let coins = Economy.coinsForFocus(seconds: focused)
        let xp = Economy.xpForFocus(seconds: focused)
        let levelBefore = profile.level

        profile.coins += coins
        profile.lifetimeCoins += coins
        profile.totalXP += xp
        profile.focusedSecondsTotal += focused

        let record = FocusSession(
            startedAt: session.startedAt,
            endedAt: now,
            focusedSeconds: focused,
            plannedMinutes: session.plannedMinutes,
            coinsAwarded: coins,
            xpAwarded: xp,
            questTitle: session.questTitle,
            questID: session.questID,
            didCompleteFullSession: session.hasRunOut(at: now)
        )
        context.insert(record)

        return FocusOutcome(
            focusedSeconds: focused,
            coins: coins,
            xp: xp,
            levelBefore: levelBefore,
            levelAfter: profile.level,
            questTitle: session.questTitle,
            didCompleteFullSession: record.didCompleteFullSession
        )
    }

    /// Seconds focused on a given day, for the header readout.
    static func focusedSeconds(in sessions: [FocusSession], on day: Date, calendar: Calendar = .current) -> Int {
        sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.focusedSeconds }
    }
}
