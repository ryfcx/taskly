//
//  TodayView.swift
//  Taskly
//

import SwiftUI
import SwiftData

struct TodayView: View {
    var profile: PlayerProfile

    @Environment(\.modelContext) private var context
    @Environment(SessionState.self) private var session

    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }, sort: \TaskItem.sortIndex)
    private var tasks: [TaskItem]

    @State private var dayOffset = 0
    @State private var categoryFilter: TaskCategory?
    @State private var editingTask: TaskItem?
    @State private var detailTask: TaskItem?
    @State private var isPresentingTemplates = false
    @State private var isPresentingEditor = false

    /// Computed rather than stored so a screen left open overnight rolls over correctly.
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    /// The day currently being shown. Offset 0 is today, 1 is tomorrow.
    private var selectedDay: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: today) ?? today
    }

    /// Future days are read only: you can queue and edit quests but not clear them early.
    private var isPlanningAhead: Bool { dayOffset > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    TodayHeader(
                        profile: profile,
                        dayOffset: $dayOffset,
                        day: selectedDay,
                        completed: completed.count,
                        total: scheduled.count,
                        availableXP: availableXP,
                        reminderCount: scheduled.filter(\.reminderEnabled).count
                    )

                    if scheduled.isEmpty {
                        emptyState
                    } else {
                        if availableCategories.count > 1 {
                            categoryFilterBar
                        }
                        questSections
                        if isPlanningAhead { addAnotherButton }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
            .tabBarClearance()
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $detailTask) { task in
                QuestDetailView(task: task, profile: profile)
            }
            .sheet(item: $editingTask) { task in
                QuestEditorView(mode: .edit(task), sortIndexHint: tasks.count)
            }
            .sheet(isPresented: $isPresentingEditor) {
                QuestEditorView(
                    mode: .create,
                    sortIndexHint: tasks.count,
                    defaultStartDay: selectedDay
                )
            }
            .sheet(isPresented: $isPresentingTemplates) {
                TemplateGalleryView(sortIndexHint: tasks.count, startDay: selectedDay)
            }
            .overlay {
                ConfettiBurst(isActive: session.confettiTrigger > 0)
                    .id(session.confettiTrigger)
            }
            .onAppear { session.planningDay = selectedDay }
            .onChange(of: dayOffset) { _, _ in
                categoryFilter = nil
                session.planningDay = selectedDay
            }
        }
    }

    // MARK: - Derived data

    private var scheduled: [TaskItem] {
        tasks.filter { $0.isScheduled(on: selectedDay) }
    }

    private var filtered: [TaskItem] {
        guard let categoryFilter else { return scheduled }
        return scheduled.filter { $0.category == categoryFilter }
    }

    private var completed: [TaskItem] {
        scheduled.filter { $0.isCompleted(on: selectedDay) }
    }

    private var overdue: [TaskItem] {
        guard !isPlanningAhead else { return [] }
        return filtered.filter { $0.isOverdue && !$0.isCompleted(on: selectedDay) }
    }

    private var pending: [TaskItem] {
        filtered.filter { !$0.isCompleted(on: selectedDay) && !(!isPlanningAhead && $0.isOverdue) }
    }

    private var done: [TaskItem] {
        filtered.filter { $0.isCompleted(on: selectedDay) }
    }

    /// XP still sitting on the board for the selected day.
    private var availableXP: Int {
        QuestEngine.remainingXP(allTasks: tasks, on: selectedDay)
    }

    private var availableCategories: [TaskCategory] {
        let present = Set(scheduled.map(\.category))
        return TaskCategory.allCases.filter { present.contains($0) }
    }

    // MARK: - Sections

    @ViewBuilder
    private var questSections: some View {
        if !overdue.isEmpty {
            section(title: "Overdue", subtitle: "Past their due date", tasks: overdue)
        }

        if !pending.isEmpty {
            section(
                title: isPlanningAhead ? "Queued up" : "On the board",
                subtitle: nil,
                accessory: isPlanningAhead ? "\(pending.count) quests" : "\(pending.count) left",
                tasks: pending
            )
        }

        if !done.isEmpty {
            section(
                title: "Cleared",
                subtitle: nil,
                accessory: "+\(earnedXP) XP",
                tasks: done
            )
        }

        if !isPlanningAhead, pending.isEmpty, overdue.isEmpty, !scheduled.isEmpty {
            allClearBanner
        }
    }

    private var earnedXP: Int {
        done.reduce(0) { $0 + ($1.completion(on: selectedDay)?.xpAwarded ?? 0) }
    }

    private func section(title: String, subtitle: String?, accessory: String? = nil, tasks list: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, subtitle: subtitle, accessory: accessory)

            ForEach(list) { task in
                QuestRow(
                    task: task,
                    day: selectedDay,
                    isCompleted: task.isCompleted(on: selectedDay),
                    isLocked: isPlanningAhead,
                    onToggle: { toggle(task) },
                    onOpen: { detailTask = task }
                )
                .contextMenu {
                    Button {
                        editingTask = task
                    } label: {
                        Label("Edit quest", systemImage: "pencil")
                    }

                    if !isPlanningAhead {
                        Button {
                            toggle(task)
                        } label: {
                            Label(
                                task.isCompleted(on: selectedDay) ? "Mark as not done" : "Complete",
                                systemImage: task.isCompleted(on: selectedDay) ? "arrow.uturn.backward" : "checkmark"
                            )
                        }
                    }

                    Button(role: .destructive) {
                        archive(task)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: list.map(\.id))
    }

    private var allClearBanner: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.goldGradient)
            Text("Board cleared")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Every quest done today. Day \(profile.currentDayStreak) of your streak is locked in.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Haptics.tap()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { dayOffset = 1 }
            } label: {
                Text("Plan tomorrow")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background { Capsule().fill(Theme.accent.opacity(0.16)) }
            }
            .buttonStyle(.pressable)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 22)
        .glassCard(fill: Theme.gold.opacity(0.07))
    }

    private var addAnotherButton: some View {
        Button {
            Haptics.tap()
            isPresentingEditor = true
        } label: {
            Label("Add another for tomorrow", systemImage: "plus")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassCard(radius: 16, fill: Theme.accent.opacity(0.08))
        }
        .buttonStyle(.pressable)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            EmptyStateCard(
                symbol: isPlanningAhead ? "calendar.badge.plus" : "sparkles",
                title: emptyTitle,
                message: emptyMessage
            )

            Button {
                Haptics.tap()
                isPresentingEditor = true
            } label: {
                GradientButtonLabel(
                    title: isPlanningAhead ? "Add a quest for tomorrow" : "Add a quest",
                    symbol: "plus"
                )
            }
            .buttonStyle(.pressable)

            Button {
                Haptics.tap()
                isPresentingTemplates = true
            } label: {
                Label("Browse starter quests", systemImage: "wand.and.stars")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .glassCard(radius: 16, fill: Theme.accent.opacity(0.08))
            }
            .buttonStyle(.pressable)
        }
    }

    private var emptyTitle: String {
        if isPlanningAhead { return "Nothing queued for tomorrow" }
        return tasks.isEmpty ? "Your board is empty" : "Nothing scheduled today"
    }

    private var emptyMessage: String {
        if isPlanningAhead {
            return "Queue up what you want waiting for you tomorrow. It stays off today's board until then."
        }
        return tasks.isEmpty
            ? "Add quests for the things you do every day, then earn XP for clearing them."
            : "None of your quests land on today. Add a one-off or adjust a schedule."
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    symbol: "square.grid.2x2.fill",
                    tint: Theme.accent,
                    isSelected: categoryFilter == nil
                ) {
                    Haptics.select()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { categoryFilter = nil }
                }

                ForEach(availableCategories) { category in
                    FilterChip(
                        title: category.title,
                        symbol: category.symbol,
                        tint: category.tint,
                        isSelected: categoryFilter == category
                    ) {
                        Haptics.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            categoryFilter = categoryFilter == category ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    // MARK: - Actions

    private func toggle(_ task: TaskItem) {
        // Clearing a quest early would award XP for a day that hasn't happened yet.
        guard !isPlanningAhead else {
            Haptics.warning()
            return
        }

        if task.isCompleted(on: selectedDay) {
            Haptics.undo()
            QuestEngine.undoCompletion(task, profile: profile, allTasks: tasks, context: context, on: selectedDay)
        } else if let outcome = QuestEngine.complete(task, profile: profile, allTasks: tasks, context: context, on: selectedDay) {
            session.present(outcome: outcome)
        }
    }

    private func archive(_ task: TaskItem) {
        Haptics.warning()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            task.isArchived = true
        }
    }
}

// MARK: - Header

struct TodayHeader: View {
    var profile: PlayerProfile
    @Binding var dayOffset: Int
    var day: Date
    var completed: Int
    var total: Int
    var availableXP: Int
    var reminderCount: Int

    private var isPlanningAhead: Bool { dayOffset > 0 }

    private var progress: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                LevelRing(level: profile.level, progress: profile.levelProgress, size: 82)

                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)

                    Text(profile.displayName)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        MetaPill(
                            symbol: profile.rank.symbol,
                            text: profile.rank.title,
                            tint: profile.rank.tint
                        )
                        if profile.currentDayStreak > 0 {
                            MetaPill(
                                symbol: "flame.fill",
                                text: "\(profile.currentDayStreak) day",
                                tint: Theme.streak
                            )
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 7) {
                HStack {
                    Text("\(profile.xpIntoLevel) / \(profile.xpForNextLevel) XP")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText())
                    Spacer()
                    Text("Level \(profile.level + 1) in \(max(0, profile.xpForNextLevel - profile.xpIntoLevel)) XP")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                XPBar(progress: profile.levelProgress)
            }

            Divider().overlay(Theme.hairline)

            daySwitcher

            HStack(spacing: 0) {
                if isPlanningAhead {
                    headerStat(value: "\(total)", label: "queued", tint: Theme.accent)
                    divider
                    headerStat(value: "\(reminderCount)", label: "with alerts", tint: Theme.pink)
                    divider
                    headerStat(value: "\(availableXP)", label: "XP on offer", tint: Theme.gold)
                } else {
                    headerStat(value: "\(completed)/\(total)", label: "cleared today", tint: Theme.success)
                    divider
                    headerStat(value: "\(Int(progress * 100))%", label: "of the board", tint: Theme.accent)
                    divider
                    headerStat(value: "\(availableXP)", label: "XP still up", tint: Theme.gold)
                }
            }
        }
        .padding(18)
        .glassCard(radius: 26)
    }

    private var daySwitcher: some View {
        HStack(spacing: 4) {
            dayChip("Today", offset: 0)
            dayChip("Tomorrow", offset: 1)
        }
        .padding(3)
        .background { Capsule().fill(Color.white.opacity(0.05)) }
    }

    private func dayChip(_ title: String, offset: Int) -> some View {
        let isSelected = dayOffset == offset

        return Button {
            guard dayOffset != offset else { return }
            Haptics.select()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { dayOffset = offset }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.black.opacity(0.85) : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background {
                    Capsule().fill(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.clear))
                }
        }
        .buttonStyle(.plain)
        // Distinct from the tab bar items, which carry the same visible labels.
        .accessibilityIdentifier("Plan \(title)")
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1, height: 26)
    }

    private func headerStat(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var greeting: String {
        guard !isPlanningAhead else {
            return "Planning · \(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))"
        }

        let hour = Calendar.current.component(.hour, from: Date())
        let part = switch hour {
        case 0..<5: "Still up"
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Winding down"
        }
        return "\(part) · \(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))"
    }
}
