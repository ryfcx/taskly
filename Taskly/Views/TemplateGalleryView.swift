//
//  TemplateGalleryView.swift
//  Taskly
//

import SwiftUI
import SwiftData

/// One-tap starter quests grouped into themed packs.
struct TemplateGalleryView: View {
    var sortIndexHint: Int
    /// Day the added quests should begin on, so planning tomorrow queues them for tomorrow.
    var startDay: Date? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }) private var existing: [TaskItem]

    @State private var selected: Set<String> = []

    private var existingTitles: Set<String> {
        Set(existing.map { $0.title.lowercased() })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    ForEach(QuestTemplates.packs) { pack in
                        packSection(pack)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .navigationTitle("Starter quests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selected.isEmpty {
                    Button {
                        addSelected()
                    } label: {
                        GradientButtonLabel(
                            title: "Add \(selected.count) \(selected.count == 1 ? "quest" : "quests")",
                            symbol: "plus.circle.fill"
                        )
                    }
                    .buttonStyle(.pressable)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selected.isEmpty)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.accentGradient)
            Text("Pick your daily quests")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Tap anything you want on your board. You can tweak XP, schedules and reminders later.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 18)
        .glassCard()
    }

    private func packSection(_ pack: QuestPack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: pack.symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(pack.category.tint)
                    .frame(width: 28, height: 28)
                    .background { Circle().fill(pack.category.tint.opacity(0.15)) }

                VStack(alignment: .leading, spacing: 1) {
                    Text(pack.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(pack.blurb)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(pack.templates) { template in
                    templateRow(template)
                }
            }
        }
    }

    private func templateRow(_ template: QuestTemplate) -> some View {
        let alreadyAdded = existingTitles.contains(template.title.lowercased())
        let isSelected = selected.contains(template.id)

        return Button {
            guard !alreadyAdded else { return }
            Haptics.select()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                if isSelected { selected.remove(template.id) } else { selected.insert(template.id) }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: template.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(template.category.tint)
                    .frame(width: 34, height: 34)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(template.category.tint.opacity(0.15))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(alreadyAdded ? Theme.textTertiary : Theme.textPrimary)
                    HStack(spacing: 6) {
                        Text(template.recurrence == .weekly
                             ? Weekdays.summary(for: template.weekdayMask)
                             : template.recurrence.title)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                        if template.reminderMinutes != nil {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }

                Spacer(minLength: 0)

                Text("+\(template.difficulty.baseXP)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(template.difficulty.tint)

                Image(systemName: alreadyAdded ? "checkmark.circle.fill" : (isSelected ? "checkmark.circle.fill" : "plus.circle"))
                    .font(.system(size: 20))
                    .foregroundStyle(alreadyAdded ? Theme.textTertiary : (isSelected ? Theme.success : Theme.textTertiary))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .glassCard(radius: 16, fill: isSelected ? Theme.success.opacity(0.1) : Theme.surface.opacity(0.6))
            .opacity(alreadyAdded ? 0.5 : 1)
        }
        .buttonStyle(.pressable)
        .disabled(alreadyAdded)
    }

    private func addSelected() {
        let templates = QuestTemplates.all.filter { selected.contains($0.id) }
        for (offset, template) in templates.enumerated() {
            context.insert(template.makeTask(sortIndex: sortIndexHint + offset, startDay: startDay))
        }

        Haptics.success()

        if templates.contains(where: { $0.reminderMinutes != nil }) {
            Task {
                if NotificationManager.shared.authorizationStatus == .notDetermined {
                    await NotificationManager.shared.requestAuthorization()
                }
            }
        }

        dismiss()
    }
}
