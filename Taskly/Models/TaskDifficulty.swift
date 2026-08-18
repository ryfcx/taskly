//
//  TaskDifficulty.swift
//  Taskly
//

import SwiftUI

/// How much effort a quest takes, which decides its base XP payout.
enum TaskDifficulty: String, CaseIterable, Identifiable, Codable {
    case trivial
    case easy
    case normal
    case hard
    case epic
    /// Most of the day — deep work, contests, all-day builds.
    case ultra
    /// Pays enough XP to finish the current level in one clear.
    case mythic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trivial: "Trivial"
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        case .epic: "Epic"
        case .ultra: "Ultra"
        case .mythic: "Mythic"
        }
    }

    /// Short hint shown under the difficulty picker.
    var blurb: String {
        switch self {
        case .trivial: "A couple minutes"
        case .easy: "Quick and light"
        case .normal: "A solid chunk"
        case .hard: "Real effort"
        case .epic: "A big lift"
        case .ultra: "Most of the day"
        case .mythic: "Instant level up"
        }
    }

    var baseXP: Int {
        switch self {
        case .trivial: 5
        case .easy: 10
        case .normal: 20
        case .hard: 35
        case .epic: 60
        case .ultra: 120
        // Floor only — QuestEngine awards at least enough to finish the current level.
        case .mythic: 300
        }
    }

    /// Number of filled pips drawn in the difficulty indicator.
    var pips: Int {
        switch self {
        case .trivial: 1
        case .easy: 2
        case .normal: 3
        case .hard: 4
        case .epic: 5
        case .ultra: 6
        case .mythic: 7
        }
    }

    static var maxPips: Int { allCases.map(\.pips).max() ?? 5 }

    var tint: Color {
        switch self {
        case .trivial: Color(hex: 0x8E8AA6)
        case .easy: Color(hex: 0x35D6A4)
        case .normal: Color(hex: 0x4D8DFF)
        case .hard: Color(hex: 0xFFA23A)
        case .epic: Color(hex: 0xFF4D6D)
        case .ultra: Color(hex: 0xC77DFF)
        case .mythic: Color(hex: 0xFFE566)
        }
    }
}
