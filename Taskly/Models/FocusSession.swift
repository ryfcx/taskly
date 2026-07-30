//
//  FocusSession.swift
//  Taskly
//

import Foundation
import SwiftData

/// A logged stretch of focused work. The quest title is snapshotted rather than related,
/// so history survives the quest being edited, archived or deleted.
@Model
final class FocusSession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date = Date()
    /// Time actually spent running, which excludes anything spent paused.
    var focusedSeconds: Int = 0
    var plannedMinutes: Int = 25
    var coinsAwarded: Int = 0
    var xpAwarded: Int = 0
    /// Empty for a freeform session that was not tied to a quest.
    var questTitle: String = ""
    var questID: UUID?
    /// Whether the player ran the clock all the way down rather than finishing early.
    var didCompleteFullSession: Bool = false

    init(
        startedAt: Date,
        endedAt: Date,
        focusedSeconds: Int,
        plannedMinutes: Int,
        coinsAwarded: Int,
        xpAwarded: Int,
        questTitle: String,
        questID: UUID?,
        didCompleteFullSession: Bool
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.focusedSeconds = focusedSeconds
        self.plannedMinutes = plannedMinutes
        self.coinsAwarded = coinsAwarded
        self.xpAwarded = xpAwarded
        self.questTitle = questTitle
        self.questID = questID
        self.didCompleteFullSession = didCompleteFullSession
    }
}

extension FocusSession {
    var day: Date { Calendar.current.startOfDay(for: startedAt) }

    var focusedMinutes: Int { focusedSeconds / 60 }

    var label: String { questTitle.isEmpty ? "Freeform focus" : questTitle }

    var durationSummary: String {
        Economy.durationLabel(seconds: focusedSeconds)
    }
}
