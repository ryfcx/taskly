//
//  QuestEditorView.swift
//  Taskly
//

import SwiftUI
import SwiftData

struct QuestEditorView: View {
    enum Mode {
        case create
        case edit(TaskItem)
        case prefilled(QuestTemplate)
    }

    /// Which day a new quest should land on. Set by the Today tab so planning tomorrow
    /// creates quests that start tomorrow.
    enum StartOption: Hashable {
        case today
        case tomorrow
        case custom
    }

    var mode: Mode
    var sortIndexHint: Int
    var defaultStartDay: Date? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var category: TaskCategory = .routine
    @State private var difficulty: TaskDifficulty = .easy
    @State private var recurrence: RecurrenceKind = .daily
    @State private var weekdayMask = Weekdays.all
    @State private var iconName = "checkmark.seal.fill"
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var reminderEnabled = false
    @State private var reminderTime = PlayerProfile.date(fromMinutes: 8 * 60)
    @State private var startOption: StartOption = .today
    @State private var customStartDate = Date()
    @State private var isPresentingIconPicker = false
    @State private var didLoad = false

    private var existingTask: TaskItem? {
        if case let .edit(task) = mode { return task }
        return nil
    }

    private var isEditing: Bool { existingTask != nil }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (recurrence != .weekly || weekdayMask & Weekdays.all != 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    previewCard
                    titleSection
                    categorySection
                    difficultySection
                    startSection
                    scheduleSection
                    reminderSection
                    if !isEditing { suggestionsSection }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .navigationTitle(isEditing ? "Edit quest" : "New quest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isPresentingIconPicker) {
                IconPickerView(selection: $iconName, category: category)
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear(perform: load)
    }

    // MARK: - Sections

    private var previewCard: some View {
        HStack(spacing: 13) {
            Button {
                Haptics.tap()
                isPresentingIconPicker = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(category.tint)
                        .frame(width: 56, height: 56)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(category.tint.opacity(0.16))
                        }

                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textPrimary, Theme.surfaceElevated)
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.pressable)

            VStack(alignment: .leading, spacing: 5) {
                Text(title.isEmpty ? "Name your quest" : title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(title.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    MetaPill(symbol: category.symbol, text: category.title, tint: category.tint)
                    MetaPill(symbol: "bolt.fill", text: "+\(difficulty.baseXP) XP", tint: Theme.gold)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard()
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Quest")

            VStack(spacing: 0) {
                TextField("", text: $title, prompt: Text("e.g. Study USACO").foregroundStyle(Theme.textTertiary))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(14)

                Divider().overlay(Theme.hairline).padding(.leading, 14)

                TextField(
                    "",
                    text: $notes,
                    prompt: Text("Notes (optional)").foregroundStyle(Theme.textTertiary),
                    axis: .vertical
                )
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1...4)
                .padding(14)
            }
            .glassCard()
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Category", subtitle: category.blurb)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(TaskCategory.allCases) { option in
                    Button {
                        Haptics.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            // Keep the icon in sync unless the player has picked a custom one.
                            if iconName == category.symbol || iconName == "checkmark.seal.fill" {
                                iconName = option.symbol
                            }
                            category = option
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 17, weight: .semibold))
                            Text(option.title)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(category == option ? Color.black.opacity(0.85) : option.tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(category == option ? AnyShapeStyle(option.tint) : AnyShapeStyle(option.tint.opacity(0.12)))
                        }
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "Difficulty",
                subtitle: difficulty.blurb,
                accessory: "+\(difficulty.baseXP) XP base"
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                ForEach(TaskDifficulty.allCases) { option in
                    Button {
                        Haptics.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { difficulty = option }
                    } label: {
                        VStack(spacing: 4) {
                            Text(option.title)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Text("\(option.baseXP)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .opacity(0.75)
                        }
                        .foregroundStyle(difficulty == option ? Color.black.opacity(0.85) : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(difficulty == option ? AnyShapeStyle(option.tint) : AnyShapeStyle(Color.white.opacity(0.06)))
                        }
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Repeat")

            VStack(spacing: 12) {
                HStack(spacing: 7) {
                    ForEach(RecurrenceKind.allCases) { option in
                        Button {
                            Haptics.select()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { recurrence = option }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: option.symbol).font(.system(size: 11, weight: .bold))
                                Text(option.title).font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(recurrence == option ? Color.black.opacity(0.85) : Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(recurrence == option ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.06)))
                            }
                        }
                        .buttonStyle(.pressable)
                    }
                }

                if recurrence == .weekly {
                    weekdayPicker
                }

                if recurrence == .once {
                    Toggle(isOn: $hasDueDate.animation(.spring(response: 0.3, dampingFraction: 0.85))) {
                        Label("Set a due date", systemImage: "calendar")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .tint(Theme.accent)

                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(14)
            .glassCard()
        }
    }

    /// Lets a quest be queued for tomorrow or a later date instead of starting today.
    private var startSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: recurrence == .once ? "Do it on" : "Starts", subtitle: startSubtitle)

            VStack(spacing: 12) {
                HStack(spacing: 7) {
                    startChip("Today", option: .today, symbol: "sun.max.fill")
                    startChip("Tomorrow", option: .tomorrow, symbol: "sunrise.fill")
                    startChip("Pick a date", option: .custom, symbol: "calendar")
                }

                if startOption == .custom {
                    DatePicker(
                        "Start date",
                        selection: $customStartDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(14)
            .glassCard()
        }
    }

    private var startSubtitle: String? {
        guard startOption != .today else { return nil }
        let day = resolvedStartDay
        let label = Calendar.current.isDateInTomorrow(day)
            ? "tomorrow"
            : day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return recurrence == .once
            ? "Lands on your board \(label)"
            : "Stays off today's board until \(label)"
    }

    private func startChip(_ title: String, option: StartOption, symbol: String) -> some View {
        Button {
            Haptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { startOption = option }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                Text(title).font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(startOption == option ? Color.black.opacity(0.85) : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(startOption == option ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.06)))
            }
        }
        .buttonStyle(.pressable)
    }

    private var resolvedStartDay: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch startOption {
        case .today:
            return today
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        case .custom:
            return max(today, calendar.startOfDay(for: customStartDate))
        }
    }

    private var weekdayPicker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    let isOn = Weekdays.contains(weekdayMask, weekdayIndex: index)
                    Button {
                        Haptics.select()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            weekdayMask = Weekdays.toggling(weekdayMask, weekdayIndex: index)
                        }
                    } label: {
                        Text(Weekdays.initials[index])
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(isOn ? Color.black.opacity(0.85) : Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background {
                                Circle().fill(isOn ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.06)))
                            }
                    }
                    .buttonStyle(.pressable)
                }
            }

            HStack(spacing: 8) {
                quickDayButton("Every day", mask: Weekdays.all)
                quickDayButton("Weekdays", mask: Weekdays.weekdaysOnly)
                quickDayButton("Weekends", mask: Weekdays.weekendsOnly)
            }
        }
    }

    private func quickDayButton(_ label: String, mask: Int) -> some View {
        Button {
            Haptics.select()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { weekdayMask = mask }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(weekdayMask == mask ? Theme.accent : Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    Capsule().fill(Color.white.opacity(weekdayMask == mask ? 0.1 : 0.05))
                }
        }
        .buttonStyle(.pressable)
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Reminder", subtitle: reminderEnabled ? nil : "Get pinged if it's still open")

            VStack(spacing: 12) {
                Toggle(isOn: $reminderEnabled.animation(.spring(response: 0.3, dampingFraction: 0.85))) {
                    Label("Remind me", systemImage: "bell.badge.fill")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                }
                .tint(Theme.accent)

                if reminderEnabled {
                    DatePicker("At", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)

                    Text("Taskly skips the reminder if you've already cleared the quest.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .glassCard()
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Quick fill", subtitle: "Tap to prefill this quest")

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(QuestTemplates.all.prefix(12)) { template in
                        Button {
                            Haptics.select()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { apply(template) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: template.symbol).font(.system(size: 11, weight: .bold))
                                Text(template.title).font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(template.category.tint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background { Capsule().fill(template.category.tint.opacity(0.13)) }
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    // MARK: - Loading & saving

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        applyDefaultStartDay()

        switch mode {
        case .create:
            break
        case let .prefilled(template):
            apply(template)
        case let .edit(task):
            title = task.title
            notes = task.notes
            category = task.category
            difficulty = task.difficulty
            recurrence = task.recurrence
            weekdayMask = task.weekdayMask
            iconName = task.iconName
            hasDueDate = task.dueDate != nil
            dueDate = task.dueDate ?? Date()
            reminderEnabled = task.reminderEnabled
            reminderTime = task.reminderDate
            applyStartDay(task.firstActiveDay())
        }
    }

    private func applyDefaultStartDay() {
        guard let defaultStartDay else { return }
        applyStartDay(defaultStartDay)
    }

    private func applyStartDay(_ date: Date) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        customStartDate = day

        // A start day in the past belongs to an existing quest that already began, so it
        // presents as "Today" rather than offering to move it backwards.
        if day <= calendar.startOfDay(for: Date()) {
            startOption = .today
        } else if calendar.isDateInTomorrow(day) {
            startOption = .tomorrow
        } else {
            startOption = .custom
        }
    }

    private func apply(_ template: QuestTemplate) {
        title = template.title
        category = template.category
        difficulty = template.difficulty
        recurrence = template.recurrence
        weekdayMask = template.weekdayMask
        iconName = template.symbol
        if let minutes = template.reminderMinutes {
            reminderEnabled = true
            reminderTime = PlayerProfile.date(fromMinutes: minutes)
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let reminderMinutes = PlayerProfile.minutes(from: reminderTime)
        let resolvedDueDate = (recurrence == .once && hasDueDate) ? dueDate : nil

        if let task = existingTask {
            task.title = trimmed
            task.notes = notes
            task.category = category
            task.difficulty = difficulty
            task.recurrence = recurrence
            task.weekdayMask = weekdayMask
            task.iconName = iconName
            task.dueDate = resolvedDueDate
            task.reminderEnabled = reminderEnabled
            task.reminderMinutes = reminderMinutes
            // Only push the start day forward; an already running quest keeps its history.
            task.startDay = startOption == .today ? task.startDay : resolvedStartDay
            QuestEngine.recomputeStreak(for: task, on: Date())
        } else {
            let task = TaskItem(
                title: trimmed,
                notes: notes,
                category: category,
                difficulty: difficulty,
                recurrence: recurrence,
                weekdayMask: weekdayMask,
                dueDate: resolvedDueDate,
                reminderEnabled: reminderEnabled,
                reminderMinutes: reminderMinutes,
                iconName: iconName,
                startDay: resolvedStartDay,
                sortIndex: sortIndexHint
            )
            context.insert(task)
        }

        Haptics.success()
        requestNotificationsIfNeeded()
        dismiss()
    }

    /// The first time someone saves a quest with a reminder, ask for permission in context.
    private func requestNotificationsIfNeeded() {
        guard reminderEnabled else { return }
        Task {
            if NotificationManager.shared.authorizationStatus == .notDetermined {
                await NotificationManager.shared.requestAuthorization()
            }
        }
    }
}

// MARK: - Icon picker

struct IconPickerView: View {
    @Binding var selection: String
    var category: TaskCategory

    @Environment(\.dismiss) private var dismiss

    private var symbols: [String] {
        var seen = Set<String>()
        return (category.suggestedSymbols + TaskCategory.allCases.flatMap(\.suggestedSymbols))
            .filter { seen.insert($0).inserted }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            Haptics.select()
                            selection = symbol
                            dismiss()
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(selection == symbol ? Color.black.opacity(0.85) : category.tint)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(selection == symbol ? AnyShapeStyle(category.tint) : AnyShapeStyle(Color.white.opacity(0.06)))
                                }
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .navigationTitle("Choose an icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
