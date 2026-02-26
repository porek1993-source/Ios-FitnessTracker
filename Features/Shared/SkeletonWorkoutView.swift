// SkeletonWorkoutView.swift
import SwiftUI

/// Kostra (Skeleton) pro tréninkovou obrazovku. Zobrazuje se, než Gemini vrátí odpověď.
struct SkeletonWorkoutView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack {
                // Falešný Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 30, height: 10)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 80, height: 24)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 80, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer().frame(height: 40)
                
                // Kostra Cviku
                VStack(spacing: 24) {
                    // Animace cviku placeholder
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 250)
                    
                    // Název cviku
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 200, height: 30)
                    
                    // Tech pills
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 80, height: 40)
                        }
                    }
                    
                    // Sety
                    VStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 60)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            // Zlatý hřeb - aplikace shimmer efektu plošně na všechny šedé polštářky
            .shimmer()
        }
        .preferredColorScheme(.dark)
    }
}
