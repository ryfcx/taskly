//
//  StatsView.swift
//  Taskly
//

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    var profile: PlayerProfile

    @Query private var allTasks: [TaskItem]
    @Query(sort: \CompletionRecord.timestamp, order: .reverse) private var completions: [CompletionRecord]

    @State private var range: StatsRange = .week

    private let calendar = Calendar.current

    enum StatsRange: String, CaseIterable, Identifiable {
        case week, month, quarter

        var id: String { rawValue }
        var title: String {
            switch self {
            case .week: "7 days"
            case .month: "30 days"
            case .quarter: "90 days"
            }
        }
        var days: Int {
            switch self {
            case .week: 7
            case .month: 30
            case .quarter: 90
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    levelCard
                    rangePicker
                    xpChart
                    highlightsGrid
                    categoryBreakdown
                    consistencyCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
            .tabBarClearance()
            .screenBackground()
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Derived data

    private struct DayBucket: Identifiable {
        var id: Date { day }
        var day: Date
        var xp: Int
        var count: Int
    }

    private var buckets: [DayBucket] {
        let today = calendar.startOfDay(for: Date())
        let grouped = Dictionary(grouping: completions) { calendar.startOfDay(for: $0.day) }

        return (0..<range.days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let records = grouped[day] ?? []
            return DayBucket(day: day, xp: records.reduce(0) { $0 + $1.xpAwarded }, count: records.count)
        }
    }

    private var rangeXP: Int { buckets.reduce(0) { $0 + $1.xp } }
    private var rangeClears: Int { buckets.reduce(0) { $0 + $1.count } }
    private var activeDays: Int { buckets.filter { $0.count > 0 }.count }

    private var bestDay: DayBucket? {
        buckets.max { $0.xp < $1.xp }
    }

    /// Share of scheduled quests actually cleared over the range.
    private var completionRate: Double {
        var scheduled = 0
        var cleared = 0
        let today = calendar.startOfDay(for: Date())

        for offset in 0..<range.days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            for task in allTasks where task.matchesPattern(on: day, calendar: calendar) {
                scheduled += 1
                if task.isCompleted(on: day, calendar: calendar) { cleared += 1 }
            }
        }
        guard scheduled > 0 else { return 0 }
        return Double(cleared) / Double(scheduled)
    }

    private struct CategorySlice: Identifiable {
        var id: String { category.rawValue }
        var category: TaskCategory
        var xp: Int
        var count: Int
    }

    private var categorySlices: [CategorySlice] {
        let cutoff = calendar.date(byAdding: .day, value: -range.days, to: calendar.startOfDay(for: Date())) ?? .distantPast
        let recent = completions.filter { $0.day >= cutoff }
        let grouped = Dictionary(grouping: recent, by: \.category)

        return grouped
            .map { CategorySlice(category: $0.key, xp: $0.value.reduce(0) { $0 + $1.xpAwarded }, count: $0.value.count) }
            .sorted { $0.xp > $1.xp }
    }

    // MARK: - Sections

    private var levelCard: some View {
        HStack(spacing: 18) {
            LevelRing(level: profile.level, progress: profile.levelProgress, size: 74, tint: profile.rank.gradient)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: profile.rank.symbol)
                        .font(.system(size: 12, weight: .bold))
                    Text(profile.rank.title.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1)
                }
                .foregroundStyle(profile.rank.tint)

                Text("\(profile.totalXP) XP")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())

                Text("\(max(0, profile.xpForNextLevel - profile.xpIntoLevel)) XP to level \(profile.level + 1)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .glassCard(radius: 26)
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(StatsRange.allCases) { option in
                FilterChip(
                    title: option.title,
                    symbol: nil,
                    tint: Theme.accent,
                    isSelected: range == option
                ) {
                    Haptics.select()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { range = option }
                }
            }
            Spacer()
        }
    }

    private var xpChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "XP earned", accessory: "\(rangeXP) XP")

            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Day", bucket.day, unit: .day),
                    y: .value("XP", bucket.xp),
                    width: .fixed(barWidth)
                )
                .foregroundStyle(Theme.xpGradient)
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .frame(height: 168)
            .padding(14)
            .glassCard()
        }
    }

    private var barWidth: CGFloat {
        switch range {
        case .week: 22
        case .month: 7
        case .quarter: 2.5
        }
    }

    private var highlightsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            highlight("Quests cleared", "\(rangeClears)", "checkmark.seal.fill", Theme.success)
            highlight("Completion rate", "\(Int(completionRate * 100))%", "target", Theme.accent)
            highlight("Active days", "\(activeDays)/\(range.days)", "calendar", Theme.pink)
            highlight("Perfect days", "\(profile.perfectDays)", "crown.fill", Theme.gold)
            highlight("Day streak", "\(profile.currentDayStreak)", "flame.fill", Theme.streak)
            highlight(
                "Best day",
                bestDay.map { "\($0.xp) XP" } ?? "—",
                "star.fill",
                Theme.accentAlt
            )
        }
    }

    private func highlight(_ label: String, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(radius: 18)
    }

    @ViewBuilder
    private var categoryBreakdown: some View {
        if categorySlices.isEmpty {
            EmptyStateCard(
                symbol: "chart.pie",
                title: "No data yet",
                message: "Clear a few quests and your breakdown will show up here."
            )
        } else {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Where your XP came from")

                VStack(spacing: 12) {
                    ForEach(categorySlices) { slice in
                        VStack(spacing: 6) {
                            HStack {
                                Image(systemName: slice.category.symbol)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(slice.category.tint)
                                Text(slice.category.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(slice.xp) XP")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            XPBar(
                                progress: Double(slice.xp) / Double(max(1, categorySlices.first?.xp ?? 1)),
                                height: 7,
                                gradient: LinearGradient(
                                    colors: [slice.category.tint, slice.category.tint.mix(with: Theme.accent, by: 0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        }
                    }
                }
                .padding(14)
                .glassCard()
            }
        }
    }

    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Most consistent quests")

            let ranked = allTasks
                .filter { !$0.isArchived && $0.totalCompletions > 0 }
                .sorted { $0.currentStreak == $1.currentStreak ? $0.totalCompletions > $1.totalCompletions : $0.currentStreak > $1.currentStreak }
                .prefix(5)

            if ranked.isEmpty {
                EmptyStateCard(
                    symbol: "flame",
                    title: "No streaks yet",
                    message: "Clear the same quest two days running to start a streak."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 16)

                            Image(systemName: task.iconName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(task.category.tint)
                                .frame(width: 30, height: 30)
                                .background {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(task.category.tint.opacity(0.14))
                                }

                            Text(task.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            MetaPill(symbol: "flame.fill", text: "\(task.currentStreak)", tint: Theme.streak)
                            Text("\(task.totalCompletions)×")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)

                        if task.id != ranked.last?.id {
                            Divider().overlay(Theme.hairline).padding(.leading, 14)
                        }
                    }
                }
                .glassCard()
            }
        }
    }
}
