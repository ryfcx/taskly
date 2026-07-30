//
//  Haptics.swift
//  Taskly
//

import UIKit

/// Thin wrapper so views can fire feedback without juggling generators.
@MainActor
enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notice = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    static func tap() {
        soft.impactOccurred()
    }

    static func select() {
        selection.selectionChanged()
    }

    static func complete() {
        impact.impactOccurred(intensity: 0.9)
    }

    static func undo() {
        rigid.impactOccurred(intensity: 0.5)
    }

    static func success() {
        notice.notificationOccurred(.success)
    }

    static func warning() {
        notice.notificationOccurred(.warning)
    }

    /// A short escalating burst used for level ups.
    static func levelUp() {
        notice.notificationOccurred(.success)
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            impact.impactOccurred(intensity: 1.0)
            try? await Task.sleep(for: .milliseconds(110))
            rigid.impactOccurred(intensity: 1.0)
        }
    }
}
