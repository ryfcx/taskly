//
//  LevelUpOverlay.swift
//  Taskly
//

import SwiftUI

/// Full screen takeover shown the moment the player crosses into a new level.
struct LevelUpOverlay: View {
    var event: LevelUpEvent
    var onDismiss: () -> Void

    @State private var appeared = false
    @State private var burst = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            RadialGradient(
                colors: [event.rank.tint.opacity(0.35), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 22) {
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .strokeBorder(event.rank.tint.opacity(0.35 - Double(index) * 0.1), lineWidth: 1.5)
                            .frame(width: 130 + CGFloat(index) * 34)
                            .scaleEffect(appeared ? 1 : 0.6)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.7, dampingFraction: 0.6).delay(Double(index) * 0.08),
                                value: appeared
                            )
                    }

                    Circle()
                        .fill(event.rank.gradient)
                        .frame(width: 118, height: 118)
                        .shadow(color: event.rank.tint.opacity(0.7), radius: 26)

                    VStack(spacing: -4) {
                        Text("\(event.newLevel)")
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("LEVEL")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    ConfettiBurst(isActive: burst, particleCount: 44)
                }
                .scaleEffect(appeared ? 1 : 0.5)
                .animation(.spring(response: 0.55, dampingFraction: 0.55), value: appeared)

                VStack(spacing: 8) {
                    Text("Level up!")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    if event.rankChanged {
                        HStack(spacing: 6) {
                            Image(systemName: event.rank.symbol)
                                .font(.system(size: 13, weight: .bold))
                            Text("New rank: \(event.rank.title)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Color.black.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background { Capsule().fill(event.rank.tint) }
                    } else {
                        Text("\(event.rank.title) · keep the run going")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appeared)

                Button(action: onDismiss) {
                    Text("Nice")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 170)
                        .padding(.vertical, 14)
                        .background {
                            Capsule().fill(Theme.accentGradient)
                        }
                        .shadow(color: Theme.accent.opacity(0.5), radius: 16, y: 6)
                }
                .buttonStyle(.pressable)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.3), value: appeared)
            }
            .padding(32)
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { burst = true }
        }
    }
}
