//
//  Components.swift
//  Taskly
//

import SwiftUI

// MARK: - Level ring

/// Circular XP meter with the current level in the middle.
struct LevelRing: View {
    var level: Int
    var progress: Double
    var size: CGFloat = 88
    var lineWidth: CGFloat = 9
    var tint: LinearGradient = Theme.xpGradient

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.09), lineWidth: lineWidth)

            // A round-capped trim of zero still paints a dot, so drop the arc entirely when empty.
            if animatedProgress > 0.001 {
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Theme.accent.opacity(0.55), radius: 8)
            }

            VStack(spacing: -2) {
                Text("\(level)")
                    .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text("LEVEL")
                    .font(.system(size: size * 0.11, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { animatedProgress = progress }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { animatedProgress = newValue }
        }
    }
}

// MARK: - Bars & pills

struct XPBar: View {
    var progress: Double
    var height: CGFloat = 10
    var gradient: LinearGradient = Theme.xpGradient

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                if progress > 0.001 {
                    Capsule()
                        .fill(gradient)
                        .frame(width: max(height, proxy.size.width * min(1, progress)))
                        .shadow(color: Theme.accent.opacity(0.5), radius: 6, y: 1)
                }
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: progress)
    }
}

/// Small rounded label with an icon, used for streaks, XP and metadata.
struct MetaPill: View {
    var symbol: String
    var text: String
    var tint: Color = Theme.textSecondary
    var filled = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(filled ? Color.black.opacity(0.85) : tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule().fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14)))
        }
    }
}

struct DifficultyPips: View {
    var difficulty: TaskDifficulty

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<TaskDifficulty.maxPips, id: \.self) { index in
                Capsule()
                    .fill(index < difficulty.pips ? difficulty.tint : Color.white.opacity(0.14))
                    .frame(width: 4, height: index < difficulty.pips ? 10 : 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: difficulty)
    }
}

// MARK: - Chips

struct FilterChip: View {
    var title: String
    var symbol: String?
    var tint: Color
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.black.opacity(0.88) : Theme.textSecondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Color.white.opacity(0.06)))
            }
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Buttons

struct GradientButtonLabel: View {
    var title: String
    var symbol: String?
    var gradient: LinearGradient = Theme.accentGradient

    var body: some View {
        HStack(spacing: 8) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 15, weight: .bold))
            }
            Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(gradient)
        }
        .shadow(color: Theme.accent.opacity(0.4), radius: 14, y: 6)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    var title: String
    var subtitle: String?
    var accessory: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            if let accessory {
                Text(accessory)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

// MARK: - Empty state

struct EmptyStateCard: View {
    var symbol: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.accentGradient)
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 24)
        .glassCard()
    }
}

// MARK: - Celebration particles

/// Lightweight confetti burst. Particles are generated once and animated with a single driver.
struct ConfettiBurst: View {
    var isActive: Bool
    var particleCount = 34

    @State private var fire = false

    private struct Particle: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let color: Color
        let spin: Double
        let delay: Double
    }

    @State private var visible = false

    private let particles: [Particle]

    init(isActive: Bool, particleCount: Int = 34) {
        self.isActive = isActive
        self.particleCount = particleCount
        let palette: [Color] = [Theme.accent, Theme.pink, Theme.gold, Theme.success, Color(hex: 0x5CE1E6)]
        self.particles = (0..<particleCount).map { index in
            Particle(
                angle: Double(index) / Double(particleCount) * 360 + Double.random(in: -8...8),
                distance: CGFloat.random(in: 90...210),
                size: CGFloat.random(in: 5...11),
                color: palette[index % palette.count],
                spin: Double.random(in: -280...280),
                delay: Double.random(in: 0...0.12)
            )
        }
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 1.6)
                    .rotationEffect(.degrees(fire ? particle.spin : 0))
                    .offset(
                        x: fire ? cos(particle.angle * .pi / 180) * particle.distance : 0,
                        y: fire ? sin(particle.angle * .pi / 180) * particle.distance : 0
                    )
                    .opacity(fire ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.1).delay(particle.delay),
                        value: fire
                    )
            }
        }
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(false)
        .onAppear { if isActive { start() } }
        .onChange(of: isActive) { _, active in if active { start() } }
    }

    /// Particles rest stacked at the centre, so they stay fully hidden until a burst runs.
    private func start() {
        visible = true
        fire = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { fire = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { visible = false }
    }
}
