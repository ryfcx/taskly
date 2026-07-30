//
//  QuestDetailView.swift
//  Taskly
//

import SwiftUI
import SwiftData

struct QuestDetailView: View {
    var task: TaskItem
    var profile: PlayerProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var session

    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }) private var allTasks: [TaskItem]

    @State private var isEditing = false
    @State private var isConfirmingDelete = false

    /// Computed rather than stored so a screen left open overnight rolls over correctly.
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var isCompleted: Bool { task.isCompleted(on: today) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                if !task.notes.isEmpty { notesCard }
                statsGrid
                HistoryHeatmap(task: task)
                scheduleCard
                dangerZone
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .tabBarClearance()
        .screenBackground()
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.tap()
                    isEditing = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Edit quest")
            }
        }
        .sheet(isPresented: $isEditing) {
            QuestEditorView(mode: .edit(task), sortIndexHint: allTasks.count)
        }
        .alert("Delete this quest?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                context.delete(task)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its completion history and XP already earned will stay on your profile, but the quest is gone for good.")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 16) {
            Image(systemName: task.iconName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(task.category.tint)
                .frame(width: 72, height: 72)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(task.category.tint.opacity(0.16))
                }

            VStack(spacing: 6) {
                Text(task.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    MetaPill(symbol: task.category.symbol, text: task.category.title, tint: task.category.tint)
                    MetaPill(symbol: "bolt.fill", text: "+\(QuestEngine.projectedXP(for: task)) XP", tint: Theme.gold)
                    if task.currentStreak >= 1 {
                        MetaPill(symbol: "flame.fill", text: "\(task.currentStreak)", tint: Theme.streak)
                    }
                }
            }

            Button {
                toggle()
            } label: {
                GradientButtonLabel(
                    title: completeButtonTitle,
                    symbol: isCompleted ? "arrow.uturn.backward" : "checkmark",
                    gradient: isCompleted
                        ? LinearGradient(colors: [Theme.surfaceElevated, Theme.surface], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Theme.success, Theme.success.mix(with: Theme.accent, by: 0.4)], startPoint: .leading, endPoint: .trailing)
                )
            }
            .buttonStyle(.pressable)
            .disabled(!task.isScheduled(on: today) && !isCompleted)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard(radius: 26)
    }

    private var completeButtonTitle: String {
        if isCompleted { return "Mark as not done" }
        if let startLabel = task.startDayLabel { return "Starts \(startLabel)" }
        return "Complete quest"
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notes")
            Text(task.notes)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .glassCard()
        }
    }

    // MARK: - Stats

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Track record")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                statTile("Current streak", "\(task.currentStreak)", "flame.fill", Theme.streak)
                statTile("Best streak", "\(task.bestStreak)", "trophy.fill", Theme.gold)
                statTile("Total clears", "\(task.totalCompletions)", "checkmark.seal.fill", Theme.success)
                statTile("XP earned", "\(task.completions.reduce(0) { $0 + $1.xpAwarded })", "bolt.fill", Theme.accent)
            }
        }
    }

    private func statTile(_ label: String, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(radius: 18)
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Schedule")

            VStack(spacing: 0) {
                if let startLabel = task.startDayLabel {
                    detailRow("Starts", startLabel, "calendar.badge.clock")
                    Divider().overlay(Theme.hairline)
                }
                detailRow("Repeats", task.scheduleSummary, "repeat")
                Divider().overlay(Theme.hairline)
                detailRow("Difficulty", "\(task.difficulty.title) · \(task.difficulty.baseXP) XP", "gauge.with.dots.needle.50percent")
                Divider().overlay(Theme.hairline)
                detailRow(
                    "Reminder",
                    task.reminderEnabled ? QuestRow.timeLabel(task.reminderMinutes) : "Off",
                    task.reminderEnabled ? "bell.fill" : "bell.slash"
                )
                if let due = task.dueDate {
                    Divider().overlay(Theme.hairline)
                    detailRow("Due", due.formatted(.dateTime.month(.abbreviated).day().year()), "calendar")
                }
            }
            .glassCard()
        }
    }

    private func detailRow(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var dangerZone: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.tap()
                withAnimation { task.isArchived.toggle() }
            } label: {
                Label(task.isArchived ? "Restore quest" : "Archive quest", systemImage: task.isArchived ? "arrow.uturn.backward" : "archivebox")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .glassCard(radius: 16)
            }
            .buttonStyle(.pressable)

            Button {
                Haptics.warning()
                isConfirmingDelete = true
            } label: {
                Label("Delete quest", systemImage: "trash")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .glassCard(radius: 16, fill: Theme.danger.opacity(0.08))
            }
            .buttonStyle(.pressable)
        }
    }

    private func toggle() {
        if isCompleted {
            Haptics.undo()
            QuestEngine.undoCompletion(task, profile: profile, allTasks: allTasks, context: context, on: today)
        } else if let outcome = QuestEngine.complete(task, profile: profile, allTasks: allTasks, context: context, on: today) {
            session.present(outcome: outcome)
        }
    }
}

// MARK: - History heatmap

/// GitHub style grid of the last 15 weeks of activity for one quest.
struct HistoryHeatmap: View {
    var task: TaskItem

    private let weeks = 15
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Last \(weeks) weeks", accessory: "\(completedDays.count) clears")

            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<weeks, id: \.self) { week in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { weekday in
                            cell(for: date(week: week, weekday: weekday))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .glassCard()
        }
    }

    private var startDate: Date {
        let today = calendar.startOfDay(for: Date())
        let weekdayIndex = calendar.component(.weekday, from: today) - 1
        let endOfWeek = calendar.date(byAdding: .day, value: 6 - weekdayIndex, to: today) ?? today
        return calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: endOfWeek) ?? today
    }

    private var completedDays: Set<Date> {
        Set(task.completions.map { calendar.startOfDay(for: $0.day) })
    }

    private func date(week: Int, weekday: Int) -> Date {
        calendar.date(byAdding: .day, value: week * 7 + weekday, to: startDate) ?? startDate
    }

    @ViewBuilder
    private func cell(for date: Date) -> some View {
        let today = calendar.startOfDay(for: Date())
        let isFuture = date > today
        let isDone = completedDays.contains(calendar.startOfDay(for: date))
        let wasScheduled = task.matchesPattern(on: date, calendar: calendar)

        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(fill(isDone: isDone, wasScheduled: wasScheduled, isFuture: isFuture))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if calendar.isDate(date, inSameDayAs: today) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .strokeBorder(Theme.textPrimary.opacity(0.7), lineWidth: 1)
                }
            }
    }

    private func fill(isDone: Bool, wasScheduled: Bool, isFuture: Bool) -> Color {
        if isDone { return task.category.tint }
        if isFuture { return Color.white.opacity(0.03) }
        if wasScheduled { return Color.white.opacity(0.09) }
        return Color.white.opacity(0.045)
    }
}
