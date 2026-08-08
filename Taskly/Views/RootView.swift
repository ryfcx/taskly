//
//  RootView.swift
//  Taskly
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SessionState.self) private var session

    @Query private var profiles: [PlayerProfile]
    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }) private var tasks: [TaskItem]

    @State private var isPresentingEditor = false
    @State private var focus = FocusController()

    var body: some View {
        @Bindable var session = session

        ZStack {
            Theme.base.ignoresSafeArea()

            if let profile = profiles.first {
                TabView(selection: $session.selectedTab) {
                    TodayView(profile: profile)
                        .tag(AppTab.today)
                        .toolbar(.hidden, for: .tabBar)

                    FocusView(profile: profile)
                        .tag(AppTab.focus)
                        .toolbar(.hidden, for: .tabBar)

                    StatsView(profile: profile)
                        .tag(AppTab.stats)
                        .toolbar(.hidden, for: .tabBar)

                    ProfileView(profile: profile)
                        .tag(AppTab.profile)
                        .toolbar(.hidden, for: .tabBar)
                }
                .environment(focus)
                .overlay(alignment: .bottom) {
                    TasklyTabBar(selection: $session.selectedTab) {
                        Haptics.tap()
                        isPresentingEditor = true
                    }
                }
                .sheet(isPresented: $isPresentingEditor) {
                    QuestEditorView(
                        mode: .create,
                        sortIndexHint: tasks.count,
                        defaultStartDay: defaultStartDay
                    )
                }
                .overlay(alignment: .bottom) {
                    if let toast = session.xpToast {
                        XPToastView(toast: toast)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, Theme.tabBarClearance - 4)
                    }
                }
                .overlay {
                    if let event = session.levelUpEvent {
                        LevelUpOverlay(event: event) { session.dismissLevelUp() }
                            .transition(.opacity)
                            .zIndex(10)
                    }
                }
                .task { await bootstrap(profile: profile) }
                .onChange(of: scheduleSignature) { _, _ in refreshNotifications(profile: profile) }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await NotificationManager.shared.refreshAuthorizationStatus() }
                    refreshNotifications(profile: profile)
                }
            } else {
                ProgressView()
                    .tint(Theme.accent)
                    .task { createProfileIfNeeded() }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: session.levelUpEvent)
    }

    /// While the Today tab is showing a future day, the add button queues quests for that day.
    private var defaultStartDay: Date? {
        session.selectedTab == .today ? session.planningDay : nil
    }

    // MARK: - Bootstrapping

    private func createProfileIfNeeded() {
        guard profiles.isEmpty else { return }
        context.insert(PlayerProfile())
    }

    private func bootstrap(profile: PlayerProfile) async {
        // Streaks depend on "today", so re-derive them whenever the app opens.
        QuestEngine.recomputeDayStreak(profile: profile, allTasks: tasks)
        for task in tasks {
            QuestEngine.recomputeStreak(for: task, on: Date(), profile: profile)
        }
        await NotificationManager.shared.refreshAuthorizationStatus()
        refreshNotifications(profile: profile)
    }

    private func refreshNotifications(profile: PlayerProfile) {
        NotificationManager.shared.scheduleRefresh(tasks: tasks, profile: profile)
    }

    /// Changes to anything that affects the notification queue, folded into one value
    /// so a single `onChange` can trigger a reschedule.
    private var scheduleSignature: Int {
        var hasher = Hasher()
        hasher.combine(tasks.count)
        for task in tasks {
            hasher.combine(task.id)
            hasher.combine(task.title)
            hasher.combine(task.reminderEnabled)
            hasher.combine(task.reminderMinutes)
            hasher.combine(task.recurrenceRaw)
            hasher.combine(task.weekdayMask)
            hasher.combine(task.difficultyRaw)
            hasher.combine(task.lastCompletedDay)
            hasher.combine(task.dueDate)
            hasher.combine(task.startDay)
        }
        if let profile = profiles.first {
            hasher.combine(profile.notificationsEnabled)
            hasher.combine(profile.morningBriefingEnabled)
            hasher.combine(profile.morningBriefingMinutes)
            hasher.combine(profile.eveningNudgeEnabled)
            hasher.combine(profile.eveningNudgeMinutes)
            hasher.combine(profile.streakAlertsEnabled)
            hasher.combine(profile.encouragementEnabled)
            hasher.combine(profile.encouragementPingsPerDay)
            hasher.combine(profile.buildExpiryAlertsEnabled)
            hasher.combine(profile.breakStartDay)
            hasher.combine(profile.breakEndDay)
            hasher.combine(profile.currentDayStreak)
        }
        return hasher.finalize()
    }
}

// MARK: - Floating tab bar

struct TasklyTabBar: View {
    @Binding var selection: AppTab
    var onAdd: () -> Void

    @Namespace private var indicator

    private let leading: [AppTab] = [.today, .focus]
    private let trailing: [AppTab] = [.stats, .profile]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(leading) { tab in
                tabButton(tab)
            }

            addButton
                .padding(.horizontal, 4)

            ForEach(trailing) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay { Capsule().fill(Theme.surface.opacity(0.6)) }
                .overlay { Capsule().strokeBorder(Theme.hairlineStrong, lineWidth: 1) }
                .shadow(color: .black.opacity(0.5), radius: 22, y: 10)
        }
        .clipShape(Capsule(style: .continuous))
        .padding(.horizontal, 22)
        .padding(.bottom, 6)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        return Button {
            guard selection != tab else { return }
            Haptics.select()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolEffect(.bounce, value: isSelected)
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Theme.accent.opacity(0.22))
                        .matchedGeometryEffect(id: "tab", in: indicator)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background {
                    Circle()
                        .fill(Theme.accentGradient)
                        .shadow(color: Theme.accent.opacity(0.6), radius: 12, y: 4)
                }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("New quest")
    }
}

// MARK: - XP toast

struct XPToastView: View {
    var toast: XPToast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toastIcon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(toast.isBonus ? Theme.gold : Theme.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(toastHeadline)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(toast.label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .glassCard(radius: 18, fill: Theme.surfaceElevated.opacity(0.85))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .padding(.horizontal, 40)
    }

    private var toastIcon: String {
        if toast.coins < 0 { return "gift.fill" }
        if toast.amount == 0, toast.coins > 0 { return "dollarsign.circle.fill" }
        return toast.isBonus ? "crown.fill" : "bolt.fill"
    }

    private var toastHeadline: String {
        if toast.coins < 0 { return "−\(-toast.coins) coins" }
        if toast.amount > 0, toast.coins > 0 { return "+\(toast.amount) XP · +\(toast.coins)" }
        if toast.amount > 0 { return "+\(toast.amount) XP" }
        if toast.coins > 0 { return "+\(toast.coins) coins" }
        return toast.label
    }
}
