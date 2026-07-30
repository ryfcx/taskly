//
//  RewardEditorView.swift
//  Taskly
//

import SwiftUI
import SwiftData

struct RewardEditorView: View {
    enum Mode {
        case create
        case edit(Reward)
    }

    var mode: Mode
    var sortIndexHint: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var cost = 50
    @State private var iconName = "gift.fill"
    @State private var didLoad = false

    private var existing: Reward? {
        if case let .edit(reward) = mode { return reward }
        return nil
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && cost > 0
    }

    private static let icons = [
        "gift.fill", "gamecontroller.fill", "tv.fill", "cup.and.saucer.fill",
        "takeoutbag.and.cup.and.straw.fill", "bag.fill", "beach.umbrella.fill",
        "film.fill", "headphones", "book.fill", "figure.run", "cart.fill",
        "fork.knife", "bed.double.fill", "music.note", "sparkles"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    previewCard
                    fieldsCard
                    costCard
                    iconGrid
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .navigationTitle(existing == nil ? "New reward" : "Edit reward")
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
        }
        .onAppear(perform: load)
    }

    private var previewCard: some View {
        HStack(spacing: 13) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .frame(width: 56, height: 56)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.gold.opacity(0.16))
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(title.isEmpty ? "Name your reward" : title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(title.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                    .lineLimit(1)

                Text("\(cost) coins")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.gold)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard()
    }

    private var fieldsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Reward")

            VStack(spacing: 0) {
                TextField("Title", text: $title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(14)

                Divider().overlay(Theme.hairline)

                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2...4)
                    .padding(14)
            }
            .glassCard()
        }
    }

    private var costCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Price", subtitle: "What this treat is worth to you")

            VStack(spacing: 12) {
                HStack(spacing: 7) {
                    ForEach([25, 50, 100, 200], id: \.self) { amount in
                        costChip(amount)
                    }
                }

                Stepper(value: $cost, in: 5...2000, step: 5) {
                    Text("\(cost) coins")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(14)
            .glassCard()
        }
    }

    private func costChip(_ amount: Int) -> some View {
        let isSelected = cost == amount

        return Button {
            Haptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { cost = amount }
        } label: {
            Text("\(amount)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.black.opacity(0.85) : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(Color.white.opacity(0.06)))
                }
        }
        .buttonStyle(.pressable)
    }

    private var iconGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Icon")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(Self.icons, id: \.self) { symbol in
                    Button {
                        Haptics.select()
                        iconName = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(iconName == symbol ? Color.black.opacity(0.85) : Theme.gold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(iconName == symbol ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(Color.white.opacity(0.06)))
                            }
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(14)
            .glassCard()
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let reward = existing else { return }
        title = reward.title
        notes = reward.notes
        cost = reward.cost
        iconName = reward.iconName
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, cost > 0 else { return }

        if let reward = existing {
            reward.title = trimmed
            reward.notes = notes
            reward.cost = cost
            reward.iconName = iconName
        } else {
            context.insert(
                Reward(
                    title: trimmed,
                    notes: notes,
                    iconName: iconName,
                    cost: cost,
                    sortIndex: sortIndexHint
                )
            )
        }

        Haptics.success()
        dismiss()
    }
}
