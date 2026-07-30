//
//  Theme.swift
//  Taskly
//

import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {
    // Surfaces
    static let base = Color(hex: 0x08070F)
    static let surface = Color(hex: 0x15131F)
    static let surfaceElevated = Color(hex: 0x1E1B2C)
    static let hairline = Color.white.opacity(0.08)
    static let hairlineStrong = Color.white.opacity(0.16)

    // Text
    static let textPrimary = Color(hex: 0xF5F3FB)
    static let textSecondary = Color(hex: 0x9E9AB8)
    static let textTertiary = Color(hex: 0x6B6884)

    // Accents
    static let accent = Color(hex: 0x7C5CFF)
    static let accentAlt = Color(hex: 0xB44CFF)
    static let pink = Color(hex: 0xFF5CA8)
    static let success = Color(hex: 0x35D6A4)
    static let warning = Color(hex: 0xFFB020)
    static let danger = Color(hex: 0xFF5A5F)
    static let gold = Color(hex: 0xFFC94D)
    static let streak = Color(hex: 0xFF8A3D)

    static let accentGradient = LinearGradient(
        colors: [accent, accentAlt, pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let xpGradient = LinearGradient(
        colors: [Color(hex: 0x5CE1E6), accent, pink],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let goldGradient = LinearGradient(
        colors: [Color(hex: 0xFFE29A), gold, Color(hex: 0xFF9F45)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let streakGradient = LinearGradient(
        colors: [Color(hex: 0xFFC24D), streak, Color(hex: 0xFF4D6D)],
        startPoint: .top,
        endPoint: .bottom
    )

    // Layout
    static let cardRadius: CGFloat = 22
    static let tabBarClearance: CGFloat = 108
}

/// The ambient app background: near black with a few soft colour blooms behind everything.
/// Uses radial gradients rather than blurred shapes so it stays cheap enough to sit
/// behind every screen.
struct AuroraBackground: View {
    var animated = true
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Theme.base

                bloom(Theme.accent.opacity(0.40), radius: w * 0.72)
                    .offset(x: -w * 0.28, y: -h * 0.18 + (drift ? -20 : 20))

                bloom(Theme.pink.opacity(0.26), radius: w * 0.58)
                    .offset(x: w * 0.38, y: h * 0.04 + (drift ? 24 : -24))

                bloom(Color(hex: 0x2BD9C4).opacity(0.18), radius: w * 0.55)
                    .offset(x: w * 0.05, y: h * 0.62 + (drift ? -16 : 16))
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func bloom(_ color: Color, radius: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.35), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
    }
}

/// Wraps a screen in the shared ambient background.
///
/// The default soft scroll edge is too faint against this dark palette to keep a navigation
/// title readable, so the top edge uses the hard style instead.
struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background { AuroraBackground() }
            .scrollEdgeEffectStyle(.hard, for: .top)
    }
}

extension View {
    func screenBackground() -> some View { modifier(ScreenBackground()) }
}

// MARK: - Card styling

struct GlassCardModifier: ViewModifier {
    var radius: CGFloat = Theme.cardRadius
    var strokeOpacity: Double = 1
    var fill: Color = Theme.surface.opacity(0.72)

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(fill)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18 * strokeOpacity),
                                Color.white.opacity(0.04 * strokeOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func glassCard(
        radius: CGFloat = Theme.cardRadius,
        strokeOpacity: Double = 1,
        fill: Color = Theme.surface.opacity(0.72)
    ) -> some View {
        modifier(GlassCardModifier(radius: radius, strokeOpacity: strokeOpacity, fill: fill))
    }

    /// Keeps scrollable content clear of the floating tab bar.
    func tabBarClearance() -> some View {
        safeAreaPadding(.bottom, Theme.tabBarClearance)
    }
}

// MARK: - Interaction

/// Scales and dims slightly while pressed, used for every tappable card.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}
