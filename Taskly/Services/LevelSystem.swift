//
//  LevelSystem.swift
//  Taskly
//

import SwiftUI

/// Converts XP into levels using a gently ramping curve:
/// level 1 → 2 costs 100 XP, and every level after costs 45 XP more than the last.
enum LevelSystem {
    static let baseCost = 100
    static let costGrowth = 45

    /// XP needed to go from `level` to `level + 1`.
    static func xpToAdvance(fromLevel level: Int) -> Int {
        baseCost + max(0, level - 1) * costGrowth
    }

    /// Total XP required to have reached `level`.
    static func cumulativeXP(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        let steps = level - 1
        return baseCost * steps + costGrowth * (steps * (steps - 1)) / 2
    }

    static func level(forXP xp: Int) -> Int {
        guard xp > 0 else { return 1 }
        var level = 1
        while cumulativeXP(forLevel: level + 1) <= xp { level += 1 }
        return level
    }

    static func progress(forXP xp: Int) -> (level: Int, into: Int, needed: Int, fraction: Double) {
        let level = level(forXP: xp)
        let into = xp - cumulativeXP(forLevel: level)
        let needed = xpToAdvance(fromLevel: level)
        return (level, into, needed, needed > 0 ? Double(into) / Double(needed) : 0)
    }
}

/// A named tier that unlocks as the player levels up.
enum Rank: String, CaseIterable, Identifiable {
    case novice
    case apprentice
    case adept
    case expert
    case master
    case grandmaster
    case legend

    var id: String { rawValue }

    static func forLevel(_ level: Int) -> Rank {
        switch level {
        case ..<5: .novice
        case 5..<10: .apprentice
        case 10..<16: .adept
        case 16..<24: .expert
        case 24..<34: .master
        case 34..<50: .grandmaster
        default: .legend
        }
    }

    var title: String {
        switch self {
        case .novice: "Novice"
        case .apprentice: "Apprentice"
        case .adept: "Adept"
        case .expert: "Expert"
        case .master: "Master"
        case .grandmaster: "Grandmaster"
        case .legend: "Legend"
        }
    }

    var symbol: String {
        switch self {
        case .novice: "leaf.fill"
        case .apprentice: "flame.fill"
        case .adept: "bolt.fill"
        case .expert: "shield.lefthalf.filled"
        case .master: "crown.fill"
        case .grandmaster: "seal.fill"
        case .legend: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .novice: Color(hex: 0x8AD98A)
        case .apprentice: Color(hex: 0x6FC3FF)
        case .adept: Color(hex: 0x9B7BFF)
        case .expert: Color(hex: 0xFF9F45)
        case .master: Color(hex: 0xFF5CA8)
        case .grandmaster: Color(hex: 0xFFC94D)
        case .legend: Color(hex: 0x5CF2E5)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [tint, tint.mix(with: Theme.accent, by: 0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
