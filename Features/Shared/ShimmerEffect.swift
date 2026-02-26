// ShimmerEffect.swift
import SwiftUI

/// Modifikátor, který přidá efekt "Shimmeru" (procházející šikmé vlny).
struct ShimmerEffect: ViewModifier {
    @State private var isInitialState = true

    func body(content: Content) -> some View {
        content
            .mask(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .black.opacity(0.3),
                        .black,
                        .black.opacity(0.3)
                    ]),
                    startPoint: (isInitialState ? .init(x: -0.3, y: -0.3) : .init(x: 1, y: 1)),
                    endPoint:   (isInitialState ? .init(x: 0, y: 0)       : .init(x: 1.3, y: 1.3))
                )
            )
            .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isInitialState)
            .onAppear {
                isInitialState = false
            }
    }
}

extension View {
    /// Aplikuje shimmer efekt, vhodný pro skeleton načítání.
    func shimmer() -> some View {
        self.modifier(ShimmerEffect())
    }
}
