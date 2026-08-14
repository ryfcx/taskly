//
//  QuestRow.swift
//  Taskly
//

import SwiftUI

/// A single quest card. Tapping the check clears it; tapping the body opens details.
struct QuestRow: View {
    var task: TaskItem
    var day: Date
    var isCompleted: Bool
    var isSkipped: Bool = false
    /// Set when showing a future day, where quests can be queued but not cleared yet.
    var isLocked: Bool = false
    /// Shows a grip so the row can be dragged to reorder the board.
    var showsDragHandle: Bool = false
    var onToggle: () -> Void
    var onOpen: () -> Void

    @State private var checkScale: CGFloat = 1

    private var isResolved: Bool { isCompleted || isSkipped }

    var body: some View {
        HStack(spacing: 13) {
            if isLocked {
                queuedBadge
            } else if isSkipped {
                skippedBadge
            } else {
                checkButton
            }

            Button(action: onOpen) {
                HStack(spacing: 12) {
                    iconTile

                    VStack(alignment: .leading, spacing: 5) {
                        Text(task.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(isResolved ? Theme.textTertiary : Theme.textPrimary)
                            .strikethrough(isCompleted, color: Theme.textTertiary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        metadata
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(trailingLabel)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(trailingColor)
                            .contentTransition(.numericText())
                        DifficultyPips(difficulty: task.difficulty)
                    }
                }
            }
            .buttonStyle(.plain)

            if showsDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 36)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Drag to reorder \(task.title)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .glassCard(fill: isResolved ? Theme.surface.opacity(0.4) : Theme.surface.opacity(0.72))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(task.category.tint.opacity(isResolved ? 0.3 : 0.9))
                .frame(width: 3.5)
                .padding(.vertical, 16)
                .padding(.leading, 1)
        }
        .opacity(isResolved ? 0.72 : 1)
    }

    private var trailingLabel: String {
        if isSkipped { return "Skip" }
        if isCompleted { return "+\(earnedXP)" }
        return "+\(QuestEngine.projectedXP(for: task))"
    }

    private var trailingColor: Color {
        if isSkipped { return Theme.textTertiary }
        if isCompleted { return Theme.success }
        return Theme.textPrimary
    }

    private var earnedXP: Int {
        task.completion(on: day)?.xpAwarded ?? task.difficulty.baseXP
    }

    private var queuedBadge: some View {
        Image(systemName: "clock")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.textTertiary)
            .frame(width: 28, height: 28)
            .background {
                Circle().strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
            }
            .accessibilityLabel("\(task.title), queued for later")
    }

    private var skippedBadge: some View {
        Image(systemName: "forward.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.textTertiary)
            .frame(width: 28, height: 28)
            .background {
                Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 2)
            }
            .accessibilityLabel("\(task.title), skipped for today")
    }

    private var checkButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { checkScale = 1.25 }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6).delay(0.08)) { checkScale = 1 }
            onToggle()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(
                        isCompleted ? AnyShapeStyle(Theme.success) : AnyShapeStyle(Theme.hairlineStrong),
                        lineWidth: 2
                    )
                    .frame(width: 28, height: 28)

                if isCompleted {
                    Circle()
                        .fill(Theme.success)
                        .frame(width: 28, height: 28)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.85))
                }
            }
            .scaleEffect(checkScale)
            .contentShape(Circle().inset(by: -8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCompleted ? "Mark \(task.title) as not done" : "Complete \(task.title)")
    }

    private var iconTile: some View {
        Image(systemName: task.iconName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isResolved ? Theme.textTertiary : task.category.tint)
            .frame(width: 36, height: 36)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(task.category.tint.opacity(isResolved ? 0.08 : 0.16))
            }
    }

    @ViewBuilder
    private var metadata: some View {
        HStack(spacing: 6) {
            MetaPill(symbol: task.category.symbol, text: task.category.title, tint: task.category.tint)

            if isSkipped {
                MetaPill(symbol: "forward.fill", text: "Skipped", tint: Theme.textTertiary)
            } else if task.currentStreak >= 2 {
                MetaPill(symbol: "flame.fill", text: "\(task.currentStreak)", tint: Theme.streak)
            }

            if task.isOverdue {
                MetaPill(symbol: "exclamationmark.triangle.fill", text: "Overdue", tint: Theme.danger)
            } else if !isSkipped, task.reminderEnabled {
                MetaPill(symbol: "bell.fill", text: Self.timeLabel(task.reminderMinutes), tint: Theme.textTertiary)
            }

            if !isLocked, let startLabel = task.startDayLabel {
                MetaPill(symbol: "calendar", text: startLabel, tint: Theme.accent)
            }
        }
    }

    static func timeLabel(_ minutes: Int) -> String {
        let date = PlayerProfile.date(fromMinutes: minutes)
        return date.formatted(.dateTime.hour().minute())
    }
}
