//
//  QuestLibraryView.swift
//  Taskly
//

import SwiftUI
import SwiftData

/// Every quest you own, grouped by category, including archived ones.
struct QuestLibraryView: View {
    var profile: PlayerProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var session

    @Query(sort: \TaskItem.sortIndex) private var allTasks: [TaskItem]

    @State private var searchText = ""
    @State private var showArchived = false
    @State private var editingTask: TaskItem?
    @State private var detailTask: TaskItem?
    @State private var isPresentingTemplates = false

    /// Computed rather than stored so a screen left open overnight rolls over correctly.
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    summaryCard

                    if grouped.isEmpty {
                        EmptyStateCard(
                            symbol: searchText.isEmpty ? "tray" : "magnifyingglass",
                            title: searchText.isEmpty ? "No quests yet" : "No matches",
                            message: searchText.isEmpty
                                ? "Tap the plus button to create your first quest."
                                : "Nothing matches \"\(searchText)\"."
                        )
                    }

                    ForEach(grouped, id: \.category) { group in
                        categorySection(group.category, tasks: group.tasks)
                    }

                    if !archived.isEmpty {
                        archivedSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
            .tabBarClearance()
            .screenBackground()
            .navigationTitle("Quests")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search quests")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        isPresentingTemplates = true
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .accessibilityLabel("Starter quests")
                }
            }
            .navigationDestination(item: $detailTask) { task in
                QuestDetailView(task: task, profile: profile)
            }
            .sheet(item: $editingTask) { task in
                QuestEditorView(mode: .edit(task), sortIndexHint: allTasks.count)
            }
            .sheet(isPresented: $isPresentingTemplates) {
                TemplateGalleryView(sortIndexHint: allTasks.count)
            }
        }
    }

    // MARK: - Data

    private var active: [TaskItem] {
        allTasks.filter { !$0.isArchived && matchesSearch($0) }
    }

    private var archived: [TaskItem] {
        allTasks.filter { $0.isArchived && matchesSearch($0) }
    }

    private func matchesSearch(_ task: TaskItem) -> Bool {
        guard !searchText.isEmpty else { return true }
        return task.title.localizedCaseInsensitiveContains(searchText)
            || task.notes.localizedCaseInsensitiveContains(searchText)
            || task.category.title.localizedCaseInsensitiveContains(searchText)
    }

    private var grouped: [(category: TaskCategory, tasks: [TaskItem])] {
        TaskCategory.allCases.compactMap { category in
            let matching = active.filter { $0.category == category }
            return matching.isEmpty ? nil : (category, matching)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryStat(value: "\(active.count)", label: "active", tint: Theme.accent)
            divider
            summaryStat(value: "\(active.filter(\.reminderEnabled).count)", label: "with alerts", tint: Theme.pink)
            divider
            summaryStat(
                value: "\(active.map(\.currentStreak).max() ?? 0)",
                label: "best streak",
                tint: Theme.streak
            )
        }
        .padding(.vertical, 16)
        .glassCard()
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 26)
    }

    private func summaryStat(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    private func categorySection(_ category: TaskCategory, tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: category.title,
                subtitle: nil,
                accessory: "\(tasks.count)"
            )

            ForEach(tasks) { task in
                QuestRow(
                    task: task,
                    day: today,
                    isCompleted: task.isCompleted(on: today),
                    onToggle: { toggle(task) },
                    onOpen: { detailTask = task }
                )
                .contextMenu {
                    Button { editingTask = task } label: {
                        Label("Edit quest", systemImage: "pencil")
                    }
                    Button { duplicate(task) } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) { setArchived(task, true) } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
            }
        }
    }

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Haptics.tap()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showArchived.toggle() }
            } label: {
                HStack {
                    SectionHeader(title: "Archived", accessory: "\(archived.count)")
                    Image(systemName: showArchived ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if showArchived {
                ForEach(archived) { task in
                    HStack(spacing: 12) {
                        Image(systemName: task.iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 34, height: 34)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                            Text("\(task.totalCompletions) clears · best streak \(task.bestStreak)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        Spacer(minLength: 0)

                        Button {
                            setArchived(task, false)
                        } label: {
                            Text("Restore")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.pressable)

                        Button {
                            delete(task)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.danger)
                        }
                        .buttonStyle(.pressable)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .glassCard(radius: 16, fill: Theme.surface.opacity(0.45))
                }
            }
        }
    }

    // MARK: - Actions

    private func toggle(_ task: TaskItem) {
        guard task.isScheduled(on: today) || task.isCompleted(on: today) else {
            Haptics.warning()
            return
        }
        if task.isCompleted(on: today) {
            Haptics.undo()
            QuestEngine.undoCompletion(task, profile: profile, allTasks: allTasks, context: context, on: today)
        } else if let outcome = QuestEngine.complete(task, profile: profile, allTasks: allTasks, context: context, on: today) {
            session.present(outcome: outcome)
        }
    }

    private func duplicate(_ task: TaskItem) {
        Haptics.tap()
        let copy = TaskItem(
            title: "\(task.title) copy",
            notes: task.notes,
            category: task.category,
            difficulty: task.difficulty,
            recurrence: task.recurrence,
            weekdayMask: task.weekdayMask,
            dueDate: task.dueDate,
            reminderEnabled: task.reminderEnabled,
            reminderMinutes: task.reminderMinutes,
            iconName: task.iconName,
            sortIndex: allTasks.count
        )
        context.insert(copy)
    }

    private func setArchived(_ task: TaskItem, _ archived: Bool) {
        Haptics.tap()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            task.isArchived = archived
        }
    }

    private func delete(_ task: TaskItem) {
        Haptics.warning()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            context.delete(task)
        }
    }
}
