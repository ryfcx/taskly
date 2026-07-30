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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trivial: "Trivial"
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        case .epic: "Epic"
        }
    }

    var baseXP: Int {
        switch self {
        case .trivial: 5
        case .easy: 10
        case .normal: 20
        case .hard: 35
        case .epic: 60
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
        }
    }

    var tint: Color {
        switch self {
        case .trivial: Color(hex: 0x8E8AA6)
        case .easy: Color(hex: 0x35D6A4)
        case .normal: Color(hex: 0x4D8DFF)
        case .hard: Color(hex: 0xFFA23A)
        case .epic: Color(hex: 0xFF4D6D)
        }
    }
}
