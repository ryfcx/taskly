//
//  FocusView.swift
//  Taskly
//

import SwiftUI
import SwiftData

/// The Focus tab: run timed sessions to mint coins, then spend them on rewards.
struct FocusView: View {
    var profile: PlayerProfile

    @Environment(\.modelContext) private var context
    @Environment(SessionState.self) private var session
    @Environment(FocusController.self) private var focus

    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }, sort: \TaskItem.sortIndex)
    private var tasks: [TaskItem]

    @Query(filter: #Predicate<Reward> { !$0.isArchived }, sort: \Reward.sortIndex)
    private var rewards: [Reward]

    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var history: [FocusSession]

    @State private var selectedQuestID: UUID?
    @State private var minutes = Economy.sessionLengthChoices[1]
    @State private var editingReward: Reward?
    @State private var isCreatingReward = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    walletCard

                    if let active = focus.active {
                        activeSessionCard(active)
                    } else {
                        startCard
                    }

                    rewardsSection

                    if !history.isEmpty {
                        historySection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
            .tabBarClearance()
            .screenBackground()
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isCreatingReward) {
                RewardEditorView(mode: .create, sortIndexHint: rewards.count)
            }
            .sheet(item: $editingReward) { reward in
                RewardEditorView(mode: .edit(reward), sortIndexHint: rewards.count)
            }
            .onAppear {
                minutes = profile.defaultFocusMinutes
                if selectedQuestID == nil { selectedQuestID = pickableQuests.first?.id }
            }
        }
    }

    // MARK: - Wallet

    private var walletCard: some View {
        VStack(spacing: 15) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.goldGradient)
                    .frame(width: 58, height: 58)
                    .background {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Theme.gold.opacity(0.14))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(profile.coins)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text(profile.coins == 1 ? "coin to spend" : "coins to spend")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            Divider().overlay(Theme.hairline)

            HStack(spacing: 0) {
                walletStat(
                    value: Economy.durationLabel(seconds: focusedToday),
                    label: "focused today",
                    tint: Theme.accent
                )
                statDivider
                walletStat(value: "\(profile.lifetimeCoins)", label: "earned all time", tint: Theme.gold)
                statDivider
                walletStat(value: "\(profile.coinsSpent)", label: "spent on rewards", tint: Theme.pink)
            }
        }
        .padding(18)
        .glassCard(radius: 26)
    }

    private var statDivider: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 26)
    }

    private func walletStat(value: String, label: String, tint: Color) -> some View {
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

    // MARK: - Active session

    private func activeSessionCard(_ active: FocusController.Active) -> some View {
        // Ticks once a second purely for the readout; the totals come from wall clock stamps.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let elapsed = active.elapsedSeconds(at: now)
            let isDone = active.hasRunOut(at: now)

            VStack(spacing: 16) {
                Text(active.questTitle.isEmpty ? "Freeform focus" : active.questTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                timerRing(
                    progress: active.progress(at: now),
                    remaining: active.remainingSeconds(at: now),
                    isPaused: active.isPaused,
                    isDone: isDone
                )

                payoutLine(elapsed: elapsed, isDone: isDone)

                HStack(spacing: 10) {
                    if !isDone {
                        Button {
                            Haptics.tap()
                            if active.isPaused { focus.resume() } else { focus.pause() }
                            syncFocusAlert()
                        } label: {
                            Label(
                                active.isPaused ? "Resume" : "Pause",
                                systemImage: active.isPaused ? "play.fill" : "pause.fill"
                            )
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            }
                        }
                        .buttonStyle(.pressable)
                    }

                    Button {
                        finishSession()
                    } label: {
                        Label(finishLabel(elapsed: elapsed), systemImage: "checkmark")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.accentGradient)
                            }
                    }
                    .buttonStyle(.pressable)
                }

                Button {
                    Haptics.warning()
                    focus.discard()
                    NotificationManager.shared.cancelFocusAlert()
                } label: {
                    Text("Discard session")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .glassCard(radius: 26, fill: isDone ? Theme.success.opacity(0.08) : Theme.surface.opacity(0.72))
        }
    }

    private func timerRing(progress: Double, remaining: Int, isPaused: Bool, isDone: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(Theme.hairline, lineWidth: 13)

            if progress > 0.001 {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isDone ? AnyShapeStyle(Theme.success) : AnyShapeStyle(Theme.accentGradient),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 1) {
                Text(Economy.clockLabel(seconds: remaining))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(ringCaption(isPaused: isPaused, isDone: isDone))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isDone ? Theme.success : Theme.textTertiary)
            }
        }
        .frame(width: 186, height: 186)
        .animation(.easeInOut(duration: 0.9), value: progress)
    }

    private func ringCaption(isPaused: Bool, isDone: Bool) -> String {
        if isDone { return "time's up" }
        return isPaused ? "paused" : "remaining"
    }

    private func payoutLine(elapsed: Int, isDone: Bool) -> some View {
        let coins = Economy.coinsForFocus(seconds: elapsed)
        let xp = Economy.xpForFocus(seconds: elapsed)

        return VStack(spacing: 3) {
            Text("+\(coins) \(coins == 1 ? "coin" : "coins") · +\(xp) XP banked")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.gold)
                .contentTransition(.numericText())

            if !isDone {
                Text("Next coin in \(Economy.clockLabel(seconds: Economy.secondsToNextBlock(seconds: elapsed)))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func finishLabel(elapsed: Int) -> String {
        let coins = Economy.coinsForFocus(seconds: elapsed)
        return coins > 0 ? "Bank \(coins)" : "Finish"
    }

    // MARK: - Start a session

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What are you working on?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        questChip(title: "Freeform", symbol: "sparkles", id: nil, tint: Theme.accentAlt)
                        ForEach(pickableQuests) { task in
                            questChip(
                                title: task.title,
                                symbol: task.iconName,
                                id: task.id,
                                tint: task.category.tint
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("For how long?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 7) {
                    ForEach(Economy.sessionLengthChoices, id: \.self) { choice in
                        lengthChip(choice)
                    }
                }

                Stepper(value: $minutes, in: Economy.minimumSessionMinutes...Economy.maximumSessionMinutes, step: 5) {
                    Text("\(minutes) minutes")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .onChange(of: minutes) { _, value in
                    profile.defaultFocusMinutes = value
                }
            }

            Text("Pays \(Economy.coinsForFocus(seconds: minutes * 60)) coins and \(Economy.xpForFocus(seconds: minutes * 60)) XP, earned in 5 minute blocks.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                startSession()
            } label: {
                GradientButtonLabel(title: "Start focusing", symbol: "play.fill")
            }
            .buttonStyle(.pressable)
        }
        .padding(16)
        .glassCard(radius: 24)
    }

    private func questChip(title: String, symbol: String, id: UUID?, tint: Color) -> some View {
        let isSelected = selectedQuestID == id

        return Button {
            Haptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedQuestID = id }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.black.opacity(0.85) : Theme.textSecondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background {
                Capsule().fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Color.white.opacity(0.06)))
            }
        }
        .buttonStyle(.pressable)
    }

    private func lengthChip(_ choice: Int) -> some View {
        let isSelected = minutes == choice

        return Button {
            Haptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { minutes = choice }
        } label: {
            Text("\(choice)m")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.black.opacity(0.85) : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.06)))
                }
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Rewards

    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "Rewards",
                subtitle: rewards.isEmpty ? nil : "Cash in what you've earned",
                accessory: "\(profile.coins) coins"
            )

            if rewards.isEmpty {
                rewardsEmptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(rewards) { reward in
                        rewardRow(reward)
                    }
                }

                Button {
                    Haptics.tap()
                    isCreatingReward = true
                } label: {
                    Label("New reward", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .glassCard(radius: 16, fill: Theme.accent.opacity(0.08))
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private var rewardsEmptyState: some View {
        VStack(spacing: 14) {
            EmptyStateCard(
                symbol: "gift.fill",
                title: "No rewards yet",
                message: "Decide what your coins are worth. Set a price on the things you already treat yourself to."
            )

            Button {
                Haptics.success()
                for reward in RewardPack.makeAll() { context.insert(reward) }
            } label: {
                GradientButtonLabel(title: "Add starter rewards", symbol: "wand.and.stars")
            }
            .buttonStyle(.pressable)

            Button {
                Haptics.tap()
                isCreatingReward = true
            } label: {
                Label("Create my own", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .glassCard(radius: 16, fill: Theme.accent.opacity(0.08))
            }
            .buttonStyle(.pressable)
        }
    }

    private func rewardRow(_ reward: Reward) -> some View {
        let affordable = reward.isAffordable(with: profile.coins)

        return HStack(spacing: 12) {
            Image(systemName: reward.iconName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(affordable ? Theme.gold : Theme.textTertiary)
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.gold.opacity(affordable ? 0.16 : 0.06))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(reward.title)
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text(rewardCaption(reward, affordable: affordable))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(affordable ? Theme.textTertiary : Theme.warning)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                redeem(reward)
            } label: {
                VStack(spacing: 0) {
                    Text("\(reward.cost)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("coins")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .opacity(0.75)
                }
                .foregroundStyle(affordable ? Color.black.opacity(0.85) : Theme.textTertiary)
                .frame(width: 62)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(affordable ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                }
            }
            .buttonStyle(.pressable)
            .disabled(!affordable)
            .accessibilityLabel("Redeem \(reward.title) for \(reward.cost) coins")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(fill: Theme.surface.opacity(affordable ? 0.72 : 0.45))
        .contextMenu {
            Button {
                editingReward = reward
            } label: {
                Label("Edit reward", systemImage: "pencil")
            }

            Button(role: .destructive) {
                Haptics.warning()
                context.delete(reward)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func rewardCaption(_ reward: Reward, affordable: Bool) -> String {
        if let shortfall = reward.shortfall(with: profile.coins) {
            return "\(shortfall) more \(shortfall == 1 ? "coin" : "coins") to go"
        }
        if let summary = reward.redeemedSummary { return summary }
        return reward.notes.isEmpty ? "Ready to claim" : reward.notes
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "Recent sessions",
                accessory: Economy.durationLabel(seconds: profile.focusedSecondsTotal) + " total"
            )

            VStack(spacing: 0) {
                ForEach(recentSessions) { record in
                    HStack(spacing: 11) {
                        Image(systemName: record.didCompleteFullSession ? "checkmark.circle.fill" : "timer")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(record.didCompleteFullSession ? Theme.success : Theme.textTertiary)
                            .frame(width: 28, height: 28)
                            .background {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Theme.surfaceElevated.opacity(0.7))
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.label)
                                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text("\(record.durationSummary) · \(record.startedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        Text("+\(record.coinsAwarded)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.gold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if record.id != recentSessions.last?.id {
                        Divider().overlay(Theme.hairline).padding(.leading, 14)
                    }
                }
            }
            .glassCard()
        }
    }

    // MARK: - Derived data

    private var pickableQuests: [TaskItem] {
        let today = Calendar.current.startOfDay(for: Date())
        return tasks.filter { $0.isScheduled(on: today) && !$0.isCompleted(on: today) }
    }

    private var selectedQuest: TaskItem? {
        guard let selectedQuestID else { return nil }
        return tasks.first { $0.id == selectedQuestID }
    }

    private var focusedToday: Int {
        FocusEngine.focusedSeconds(in: history, on: Date())
    }

    private var recentSessions: [FocusSession] {
        Array(history.prefix(5))
    }

    // MARK: - Actions

    private func startSession() {
        Haptics.tap()
        focus.start(
            questID: selectedQuest?.id,
            questTitle: selectedQuest?.title ?? "",
            minutes: minutes
        )
        syncFocusAlert()
    }

    private func finishSession() {
        guard let active = focus.takeSession() else { return }
        NotificationManager.shared.cancelFocusAlert()
        session.present(focus: FocusEngine.finish(active, profile: profile, context: context))
    }

    private func redeem(_ reward: Reward) {
        guard RewardStore.redeem(reward, profile: profile) else {
            Haptics.warning()
            return
        }
        Haptics.success()
        session.showToast(
            XPToast(amount: 0, coins: -reward.cost, label: "Redeemed \(reward.title)", isBonus: false)
        )
    }

    /// Keeps the end-of-session alert lined up with the clock as it is paused and resumed.
    private func syncFocusAlert() {
        guard let active = focus.active, let end = active.projectedEnd else {
            NotificationManager.shared.cancelFocusAlert()
            return
        }

        NotificationManager.shared.scheduleFocusAlert(
            endsAt: end,
            questTitle: active.questTitle,
            coins: Economy.coinsForFocus(seconds: active.plannedSeconds),
            xp: Economy.xpForFocus(seconds: active.plannedSeconds)
        )
    }
}
