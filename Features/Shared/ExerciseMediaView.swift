// ExerciseMediaView.swift
// Agilní Fitness Trenér — Přehrávač medií
//
// ✅ WKWebView pro plynulé, paměťově nenáročné přehrávání GIF/videa ve smyčce
// ✅ Skeleton loading state
// ✅ Plně česky

import SwiftUI
import WebKit

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ExerciseMediaView  — hlavní veřejná komponenta
// MARK: ═══════════════════════════════════════════════════════════════════════

struct ExerciseMediaView: View {

    /// URL GIFu/Videa (remote nebo local). Pokud nil → chybový stav MissingMediaView.
    let gifURL: URL?

    /// Název cviku pro zobrazení a logování.
    let exerciseName: String

    /// Volitelný anglický název cviku.
    var exerciseNameEn: String? = nil

    // Internal state
    @State private var isLoading     = true
    @State private var loadFailed    = false
    @State private var glowPulse     = false

    var body: some View {
        Group {
            if let url = gifURL {
                // ── GIF přehrávač ─────────────────────────────────────────
                GIFPlayerView(
                    gifURL:    url,
                    isLoading: $isLoading,
                    hasFailed: $loadFailed
                )
                .overlay {
                    // Skeleton loader dokud se GIF nenačte
                    if isLoading {
                        skeletonOverlay
                    }
                    // Fallback pokud načtení GIFu selhalo
                    if loadFailed {
                        MissingMediaView()
                    }
                }
            } else {
                // ── Obrázek nenalezen Fallback (žádný GIF) ───────────────────────────
                MissingMediaView()
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear { glowPulse = true }
    }

    // MARK: Skeleton overlay
    private var skeletonOverlay: some View {
        ZStack {
            Color(hue: 0.62, saturation: 0.20, brightness: 0.10)

            VStack(spacing: 14) {
                ProgressView().tint(.white.opacity(0.4)).scaleEffect(1.2)
                Text("Načítám animaci…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: GIFPlayerView  — WKWebView wrapper pro GIF přehrávání
// MARK: ═══════════════════════════════════════════════════════════════════════

struct GIFPlayerView: UIViewRepresentable {
    let gifURL:    URL
    @Binding var isLoading: Bool
    @Binding var hasFailed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Povolení automatického přehrávání inline (nutné pro GIFy bez interakce)
        config.allowsInlineMediaPlayback         = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate              = context.coordinator
        webView.scrollView.isScrollEnabled      = false   // žádné scrollování
        webView.scrollView.bounces              = false
        webView.isOpaque                        = false
        webView.backgroundColor                 = .clear
        webView.scrollView.backgroundColor      = .clear
        webView.isUserInteractionEnabled        = false   // GIF je pouze pro prohlížení

        // Potlačení výchozího webového pozadí a scrollbaru
        webView.evaluateJavaScript("""
            document.body.style.margin='0';
            document.body.style.padding='0';
            document.body.style.overflow='hidden';
        """, completionHandler: nil)

        loadGIF(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Znovu načteme pouze pokud se URL změní
        if context.coordinator.lastLoadedURL != gifURL {
            context.coordinator.lastLoadedURL = gifURL
            loadGIF(in: webView)
        }
    }

    // MARK: HTML šablona pro GIF

    private func loadGIF(in webView: WKWebView) {
        let urlString = gifURL.absoluteString
        let isVideo = urlString.lowercased().hasSuffix(".mp4") || urlString.lowercased().hasSuffix(".mov")

        let mediaTag: String
        if isVideo {
            mediaTag = """
            <video autoplay loop muted playsinline>
                <source src="\(urlString)" type="video/mp4">
            </video>
            """
        } else {
            mediaTag = """
            <img src="\(urlString)"
                 alt="Animace cviku"
                 onload="document.title='loaded'"
                 onerror="document.title='error'" />
            """
        }

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body { width: 100%; height: 100%; background: #0D1117; overflow: hidden; }
          img, video {
            width: 100%;
            height: 100%;
            object-fit: cover;
            display: block;
            -webkit-user-drag: none;
            pointer-events: none;
          }
        </style>
        </head>
        <body>
          \(mediaTag)
        </body>
        <script>
            if (\(isVideo.description)) {
                let v = document.querySelector('video');
                v.addEventListener('loadeddata', () => { document.title='loaded'; });
                v.addEventListener('error', () => { document.title='error'; });
                v.play().catch(e => { document.title='error'; });
            }
        </script>
        </html>
        """

        // Načtení s baseURL nil — GIF se načte přímo z remote URL
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: GIFPlayerView
        var lastLoadedURL: URL?

        init(_ parent: GIFPlayerView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Sledujeme document.title pro detekci load/error eventů z img tagu
            webView.evaluateJavaScript("document.title") { result, _ in
                DispatchQueue.main.async {
                    if let title = result as? String {
                        if title == "error" {
                            self.parent.hasFailed = true
                        }
                        self.parent.isLoading = false
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasFailed = true
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasFailed = true
            }
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: MissingMediaView  — karta pro zobrazení chyby média
// MARK: ═══════════════════════════════════════════════════════════════════════

struct MissingMediaView: View {
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // ── Pozadí s gradientem ──────────────────────────────────────
            LinearGradient(
                colors: [
                    Color(hue: 0.62, saturation: 0.30, brightness: 0.14),
                    Color(hue: 0.62, saturation: 0.20, brightness: 0.08)
                ],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )

            // ── Dekorativní mřížka ───────────────────────────────────────
            GridPattern()
                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                .ignoresSafeArea()

            // ── Glow kruh za ikonou ──────────────────────────────────────
            Circle()
                .fill(Color.orange.opacity(0.12))
                .frame(width: 110, height: 110)
                .blur(radius: glowPulse ? 24 : 14)
                .scaleEffect(glowPulse ? 1.20 : 0.85)
                .animation(
                    .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                    value: glowPulse
                )

                // ── Obsah ────────────────────────────────────────────────────
                VStack(spacing: 18) {

                    // Ikona
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.18))
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .stroke(Color.orange.opacity(0.35), lineWidth: 1.5)
                            )

                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white.opacity(0.90))
                    }

                    // Text
                    VStack(spacing: 6) {
                        Text("Ukázka chybí")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))

                        Text("Animaci pro tento cvik\\npřidáme do databáze později.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                }
                .padding(.horizontal, 24)
        }
        .onAppear { glowPulse = true }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: GridPattern  — dekorativní mřížka pro pozadí fallback karty
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct GridPattern: Shape {
    let spacing: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Vertikální linky
        var x = spacing
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }
        // Horizontální linky
        var y = spacing
        while y < rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }
        return path
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Preview
// MARK: ═══════════════════════════════════════════════════════════════════════

#Preview("Video přehrávač + Missing Fallback") {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 24) {

                // ── Scénář 1: Validní GIF/Video URL ────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("S GIF animací")
                        .font(.caption).foregroundStyle(.white.opacity(0.4))

                    ExerciseMediaView(
                        gifURL:         URL(string: "https://media.giphy.com/media/l46Cc8cPaJJYjNkHC/giphy.gif"),
                        exerciseName:   "Benchpress s osou",
                        exerciseNameEn: "Barbell Bench Press"
                    )
                }

                // ── Scénář 2: nil GIF → Missing fallback ────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Missing fallback (gifURL = nil)")
                        .font(.caption).foregroundStyle(.white.opacity(0.4))

                    ExerciseMediaView(
                        gifURL:         nil,
                        exerciseName:   "Dřep s osou",
                        exerciseNameEn: "Barbell Back Squat"
                    )
                }

                // ── Scénář 3: Špatná URL → load selže → fallback ─────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Broken URL → fallback")
                        .font(.caption).foregroundStyle(.white.opacity(0.4))

                    ExerciseMediaView(
                        gifURL:       URL(string: "https://example.com/nonexistent.gif"),
                        exerciseName: "Mrtvý tah"
                    )
                }
            }
            .padding(20)
        }
    }
    .preferredColorScheme(.dark)
}
