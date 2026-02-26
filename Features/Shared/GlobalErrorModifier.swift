// GlobalErrorModifier.swift
// Agilní Fitness Trenér — Globální záchranná brzda chyb
//
// ✅ ViewModifier: aplikuj jednou na root view → chytá chyby z celé app
// ✅ In-app Toast: elegantní notifikace bez systémového alertu
// ✅ Automatické mizení po 4 sekundách
// ✅ Swipe-to-dismiss
// ✅ Network monitor: real-time detekce výpadku internetu
// ✅ Severity-based styling: info / warning / error

import SwiftUI
import Network

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: GlobalErrorModifier — ViewModifier
// MARK: ═══════════════════════════════════════════════════════════════════════

struct GlobalErrorModifier: ViewModifier {

    @Binding var error: AppToastError?

    // Auto-dismiss timer
    @State private var dismissTask: Task<Void, Never>?

    // Network monitor
    @StateObject private var netMonitor = NetworkMonitor()

    func body(content: Content) -> some View {
        content
            // Network loss → automatický toast
            .onChange(of: netMonitor.isConnected) { _, isConnected in
                if !isConnected {
                    show(.noInternet)
                }
                // Reconnect — skryjeme "offline" toast
                else if case .noInternet = error?.id {
                    // Nic — uživatel ví, že je zpět online
                }
            }
            // Toast overlay
            .overlay(alignment: .top) {
                if let err = error {
                    ToastView(error: err) {
                        dismiss()
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal:   .move(edge: .top).combined(with: .opacity)
                        )
                    )
                    .padding(.top, 8)
                    .zIndex(9999)  // Nad vším ostatním
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.80), value: error?.id)
            .onChange(of: error?.id) { _, newID in
                guard newID != nil else { return }
                scheduleDismiss()
            }
    }

    // MARK: - Helpers

    private func show(_ err: AppToastError) {
        withAnimation { error = err }
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)  // 4 sekundy
            guard !Task.isCancelled else { return }
            await MainActor.run { dismiss() }
        }
    }

    private func dismiss() {
        withAnimation { error = nil }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ToastView — vizuální komponenta
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct ToastView: View {
    let error:     AppToastError
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            // Ikona se severity barvou
            Image(systemName: error.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(severityColor)
                .frame(width: 24)

            // Zpráva
            Text(error.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Dismiss tlačítko
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.40))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(toastBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(severityColor.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
        .padding(.horizontal, 16)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { val in
                    // Pouze swipe nahoru (záporné y) pro dismiss
                    if val.translation.height < 0 {
                        dragOffset = val.translation.height
                    }
                }
                .onEnded { val in
                    if val.translation.height < -40 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.3)) { dragOffset = 0 }
                    }
                }
        )
    }

    private var severityColor: Color {
        switch error.severity {
        case .info:    return Color(red: 0.13, green: 0.80, blue: 0.43)
        case .warning: return Color(red: 1.0,  green: 0.68, blue: 0.20)
        case .error:   return Color(red: 1.0,  green: 0.35, blue: 0.35)
        }
    }

    @ViewBuilder
    private var toastBackground: some View {
        ZStack {
            // Blur material
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)

            // Severity tint overlay
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(severityColor.opacity(0.08))
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: NetworkMonitor — real-time detekce connectivity
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected: Bool = true

    private let monitor:  NWPathMonitor
    private let queue:    DispatchQueue

    init() {
        self.monitor = NWPathMonitor()
        self.queue   = DispatchQueue(label: "com.agilefitness.netmonitor", qos: .utility)
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            // ⚠️ pathUpdateHandler volán na background queue → přepni na MainActor
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: View Extension — sugar syntax pro snazší použití
// MARK: ═══════════════════════════════════════════════════════════════════════

extension View {
    /// Přidá globální error toast nad celou view hierarchii.
    ///
    /// Použití v App.swift:
    /// ```swift
    /// RootView()
    ///     .globalErrorToast($appEnv.globalError)
    /// ```
    func globalErrorToast(_ error: Binding<AppToastError?>) -> some View {
        modifier(GlobalErrorModifier(error: error))
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Preview
// MARK: ═══════════════════════════════════════════════════════════════════════

#Preview("GlobalErrorModifier — Toasty") {
    struct PreviewWrapper: View {
        @State private var error: AppToastError?

        var body: some View {
            ZStack {
                Color(hue: 0.62, saturation: 0.18, brightness: 0.07).ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Test globálních chyb")
                        .font(.headline).foregroundStyle(.white)

                    Button("⚠️ Warning Toast") {
                        error = .apiTimeout
                    }
                    .buttonStyle(PreviewButtonStyle(color: .orange))

                    Button("❌ Error Toast") {
                        error = AppToastError(
                            message:  "Nepodařilo se uložit trénink.",
                            icon:     "exclamationmark.triangle.fill",
                            severity: .error
                        )
                    }
                    .buttonStyle(PreviewButtonStyle(color: .red))

                    Button("✅ Success Toast") {
                        error = .savedOK
                    }
                    .buttonStyle(PreviewButtonStyle(color: .green))

                    Button("📶 No Internet") {
                        error = .noInternet
                    }
                    .buttonStyle(PreviewButtonStyle(color: .blue))
                }
            }
            .modifier(GlobalErrorModifier(error: $error))
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}

private struct PreviewButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(color.opacity(0.25)))
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
