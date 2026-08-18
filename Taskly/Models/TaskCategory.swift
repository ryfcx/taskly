//
//  TaskCategory.swift
//  Taskly
//

import SwiftUI

/// High level grouping for a quest. Drives icon defaults, colour and filtering.
enum TaskCategory: String, CaseIterable, Identifiable, Codable {
    case routine
    case study
    case build
    case fitness
    case social
    case mind
    case chores
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .routine: "Routine"
        case .study: "Study"
        case .build: "Build"
        case .fitness: "Fitness"
        case .social: "Social"
        case .mind: "Mind"
        case .chores: "Chores"
        case .other: "Other"
        }
    }

    /// Short flavour text shown when picking a category.
    var blurb: String {
        switch self {
        case .routine: "Morning & night habits"
        case .study: "Classes, reading, practice"
        case .build: "Projects and creative work"
        case .fitness: "Move, lift, stretch"
        case .social: "People you care about"
        case .mind: "Read, journal, breathe"
        case .chores: "Home & admin"
        case .other: "Everything else"
        }
    }

    var symbol: String {
        switch self {
        case .routine: "sunrise.fill"
        case .study: "book.fill"
        case .build: "hammer.fill"
        case .fitness: "figure.run"
        case .social: "bubble.left.and.bubble.right.fill"
        case .mind: "brain.head.profile"
        case .chores: "house.fill"
        case .other: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .routine: Color(hex: 0xFFA23A)
        case .study: Color(hex: 0x4D8DFF)
        case .build: Color(hex: 0xA46BFF)
        case .fitness: Color(hex: 0x35D6A4)
        case .social: Color(hex: 0xFF5CA8)
        case .mind: Color(hex: 0x3ED2E0)
        case .chores: Color(hex: 0xC9A227)
        case .other: Color(hex: 0x9C99B4)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [tint, tint.mix(with: Theme.accent, by: 0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Suggested SF Symbols offered in the icon picker for this category.
    var suggestedSymbols: [String] {
        switch self {
        case .routine: ["bed.double.fill", "sunrise.fill", "moon.stars.fill", "drop.fill", "shower.fill", "alarm.fill"]
        case .study: ["book.fill", "function", "chart.xyaxis.line", "graduationcap.fill", "pencil.and.ruler.fill", "text.book.closed.fill"]
        case .build: ["hammer.fill", "laptopcomputer", "curlybraces", "app.badge.fill", "cube.transparent.fill", "terminal.fill"]
        case .fitness: ["figure.run", "dumbbell.fill", "figure.cooldown", "heart.fill", "bicycle", "figure.pool.swim"]
        case .social: ["message.fill", "phone.fill", "person.2.fill", "envelope.fill", "gift.fill", "hand.wave.fill"]
        case .mind: ["brain.head.profile", "leaf.fill", "book.closed.fill", "waveform.path", "moon.zzz.fill", "pencil.line"]
        case .chores: ["house.fill", "trash.fill", "washer.fill", "cart.fill", "dollarsign.circle.fill", "wrench.and.screwdriver.fill"]
        case .other: ["sparkles", "star.fill", "flag.fill", "bolt.fill", "target", "checkmark.seal.fill"]
        }
    }
}
