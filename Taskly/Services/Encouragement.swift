//
//  Encouragement.swift
//  Taskly
//

import Foundation

/// Copy for the upbeat check-ins that land between the morning briefing and the evening
/// nudge. Lines are chosen from a caller supplied seed rather than at random, so the
/// pings in a day differ from each other but stay put when the queue is rebuilt.
enum Encouragement {
    struct Message: Equatable {
        var title: String
        var body: String
    }

    static func message(
        done: Int,
        total: Int,
        remainingTitles: [String],
        xp: Int,
        streak: Int,
        seed: Int
    ) -> Message {
        let remaining = max(0, total - done)
        let ratio = total > 0 ? Double(done) / Double(total) : 0

        let titles: [String]
        if remaining == 1 {
            titles = lastOne
        } else if done == 0 {
            titles = fresh
        } else if ratio >= 0.6 {
            titles = closing
        } else {
            titles = rolling
        }

        return Message(
            title: pick(titles, seed: seed),
            body: body(
                done: done,
                total: total,
                remaining: remaining,
                remainingTitles: remainingTitles,
                xp: xp,
                streak: streak
            )
        )
    }

    private static func body(
        done: Int,
        total: Int,
        remaining: Int,
        remainingTitles: [String],
        xp: Int,
        streak: Int
    ) -> String {
        if remaining == 1, let name = remainingTitles.first {
            return "\(name) is all that stands between you and a clean board · +\(xp) XP"
        }

        if done == 0 {
            if streak >= 2 {
                return "\(total) \(questWord(total)) waiting · \(xp) XP and a \(streak) day streak on the line"
            }
            return "\(total) \(questWord(total)) waiting · \(xp) XP up for grabs"
        }

        return "\(done) of \(total) cleared · \(xp) XP still on the table"
    }

    private static func pick(_ options: [String], seed: Int) -> String {
        options[abs(seed) % options.count]
    }

    private static func questWord(_ count: Int) -> String {
        count == 1 ? "quest" : "quests"
    }

    // MARK: - Lines

    private static let fresh = [
        "Clean slate, your move",
        "One quest starts the engine",
        "The board is waiting on you",
        "Momentum starts with the first one",
        "Nothing cleared yet, plenty of day left",
        "Pick the easy one and go"
    ]

    private static let rolling = [
        "You're moving",
        "That's real progress",
        "Keep it rolling",
        "The board is shrinking",
        "Good rhythm going",
        "Another one and you're ahead"
    ]

    private static let closing = [
        "Almost there",
        "Final stretch",
        "You can see the end of this",
        "Nearly a clean board",
        "Bring it home",
        "Don't stop here"
    ]

    private static let lastOne = [
        "One quest left",
        "Just one more",
        "Close it out",
        "One away from a clean board",
        "Last one standing",
        "Finish strong"
    ]
}
