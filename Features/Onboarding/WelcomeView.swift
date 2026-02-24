// WelcomeView.swift
// Agilní Fitness Trenér — Úvodní obrazovka a vstup do onboardingu

import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    @State private var animateItems = false

    var body: some View {
        ZStack {
            // ── Background Layer ──────────────────────────────────────
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()

            // Atmospheric glows
            Group {
                RadialGradient(
                    colors: [Color.blue.opacity(0.15), .clear],
                    center: .topTrailing,
                    startRadius: 0, endRadius: 500
                )
                RadialGradient(
                    colors: [Color.cyan.opacity(0.12), .clear],
                    center: .bottomLeading,
                    startRadius: 0, endRadius: 600
                )
            }
            .ignoresSafeArea()

            // ── Content ───────────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                // Hero Image / Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.3), .clear],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 240, height: 240)
                        .blur(radius: 40)

                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.7)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 10)
                }
                .scaleEffect(animateItems ? 1 : 0.8)
                .opacity(animateItems ? 1 : 0)
                .padding(.bottom, 40)

                // Title & Description
                VStack(spacing: 16) {
                    Text("Agilní Fitness\nTrenér")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .lineSpacing(-4)

                    Text("Trénink, který se přizpůsobí tvému tělu v reálném čase.")
                        .font(.system(size: 18, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 40)
                }
                .offset(y: animateItems ? 0 : 20)
                .opacity(animateItems ? 1 : 0)

                Spacer()

                // Bottom Action
                VStack(spacing: 20) {
                    Button(action: onStart) {
                        HStack(spacing: 12) {
                            Text("Začít s Jakubem")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .heavy))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.5, blue: 1.0), 
                                         Color(red: 0.1, green: 0.35, blue: 0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .blue.opacity(0.35), radius: 15, x: 0, y: 8)
                    }
                    .padding(.horizontal, 30)

                    Text("Jakub je tvůj osobní AI průvodce")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .offset(y: animateItems ? 0 : 30)
                .opacity(animateItems ? 1 : 0)
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.2)) {
                animateItems = true
            }
        }
    }
}

#Preview {
    WelcomeView(onStart: {})
}
