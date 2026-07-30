//
//  Reward.swift
//  Taskly
//

import Foundation
import SwiftData

/// Something the player buys with coins: a real world treat they have decided is worth
/// earning. Costs are set by the player, so the economy is theirs to balance.
@Model
final class Reward {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var iconName: String = "gift.fill"
    var cost: Int = 50
    var createdAt: Date = Date()
    var timesRedeemed: Int = 0
    var lastRedeemedAt: Date?
    var isArchived: Bool = false
    var sortIndex: Int = 0

    init(
        title: String,
        notes: String = "",
        iconName: String = "gift.fill",
        cost: Int = 50,
        sortIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.iconName = iconName
        self.cost = cost
        self.createdAt = Date()
        self.sortIndex = sortIndex
    }
}

extension Reward {
    func isAffordable(with coins: Int) -> Bool { coins >= cost }

    /// How many more coins are needed, or nil once it can be bought.
    func shortfall(with coins: Int) -> Int? {
        let missing = cost - coins
        return missing > 0 ? missing : nil
    }

    var redeemedSummary: String? {
        guard timesRedeemed > 0 else { return nil }
        let times = timesRedeemed == 1 ? "Redeemed once" : "Redeemed \(timesRedeemed) times"
        guard let last = lastRedeemedAt else { return times }
        return "\(times) · last \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

/// The rewards offered on a fresh install, so the shop is never an empty room.
enum RewardPack {
    static let starters: [(title: String, icon: String, cost: Int, notes: String)] = [
        ("An hour of gaming", "gamecontroller.fill", 60, "Guilt free, earned fair and square"),
        ("Episode of a show", "tv.fill", 40, "One episode, not a whole season"),
        ("Coffee shop trip", "cup.and.saucer.fill", 80, "Get out of the house for a bit"),
        ("Order takeout", "takeoutbag.and.cup.and.straw.fill", 150, "Skip cooking tonight"),
        ("Buy a small treat", "bag.fill", 200, "Something under twenty dollars"),
        ("A full day off", "beach.umbrella.fill", 500, "No quests, no guilt")
    ]

    static func makeAll() -> [Reward] {
        starters.enumerated().map { index, item in
            Reward(
                title: item.title,
                notes: item.notes,
                iconName: item.icon,
                cost: item.cost,
                sortIndex: index
            )
        }
    }
}
