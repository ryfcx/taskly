//
//  Recurrence.swift
//  Taskly
//

import Foundation

/// How often a quest comes back around.
enum RecurrenceKind: String, CaseIterable, Identifiable, Codable {
    /// Every single day.
    case daily
    /// Only on the weekdays stored in `TaskItem.weekdayMask`.
    case weekly
    /// A one-off that stays on the board until it is finished.
    case once

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Every day"
        case .weekly: "Certain days"
        case .once: "One time"
        }
    }

    var symbol: String {
        switch self {
        case .daily: "repeat"
        case .weekly: "calendar"
        case .once: "flag.fill"
        }
    }
}

/// Helpers for the `weekdayMask` bitfield. Bit 0 is Sunday through bit 6 for Saturday,
/// matching `Calendar.component(.weekday:)` offset by one.
enum Weekdays {
    static let all: Int = 0b1111111
    static let weekdaysOnly: Int = 0b0111110
    static let weekendsOnly: Int = 0b1000001

    /// Single letter labels ordered Sunday first.
    static let initials = ["S", "M", "T", "W", "T", "F", "S"]
    static let shortNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static func contains(_ mask: Int, weekdayIndex: Int) -> Bool {
        mask & (1 << weekdayIndex) != 0
    }

    static func toggling(_ mask: Int, weekdayIndex: Int) -> Int {
        mask ^ (1 << weekdayIndex)
    }

    /// A human readable summary such as "Mon, Wed, Fri" or "Weekdays".
    static func summary(for mask: Int) -> String {
        let normalized = mask & all
        switch normalized {
        case 0: return "No days"
        case all: return "Every day"
        case weekdaysOnly: return "Weekdays"
        case weekendsOnly: return "Weekends"
        default:
            let names = (0..<7).compactMap { contains(normalized, weekdayIndex: $0) ? shortNames[$0] : nil }
            return names.joined(separator: ", ")
        }
    }
}
