// ExerciseDetailView_Updated.swift
// Agilní Fitness Trenér — Aktualizovaný detail cviku s médii
//
// ✅ ExerciseMediaView (GIF / YouTube) integrována jako první sekce nahoře
// ✅ ViewModel rozšířen o gifURL computed property
// ✅ Plynulý skeleton → media přechod
// ✅ Vše česky

import SwiftUI

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ExerciseDetailView  — drop-in náhrada (přidána mediaSection nahoře)
// MARK: ═══════════════════════════════════════════════════════════════════════

struct ExerciseDetailView: View {
    let slug: String

    @StateObject private var vm = ExerciseDetailViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // ── 1. MEDIA (GIF nebo YouTube) — první věc co uživatel vidí ──
                    mediaSection

                    // ── 2. Název a kategorie ──────────────────────────────────
                    headerSection

                    // ── 3. Tagy (svaly, vybavení) ────────────────────────────
                    tagsSection

                    // ── 4. Instrukce ─────────────────────────────────────────
                    instructionsSection

                    // ── 5. YouTube tlačítko (sekundární, pod instrukcemi) ────
                    youtubeButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 0)   // mediaSection má nulový top padding (full-width)
                .padding(.bottom, 60)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task { await vm.load(slug: slug) }
    }

    // MARK: ─ Media sekce ──────────────────────────────────────────────────────

    @ViewBuilder
    private var mediaSection: some View {
        if vm.isLoadingExercise {
            // Skeleton placeholder dokud se nenačte cvik ze Supabase
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(height: 260)
                .shimmer()
                .padding(.horizontal, 0) // full-width uvnitř paddingované oblasti
                .transition(.opacity)
        } else {
            // ExerciseMediaView — automaticky rozhodne GIF vs YouTube
            ExerciseMediaView(
                gifURL:         vm.gifURL,          // nil → YouTube fallback
                exerciseName:   vm.displayName,
                exerciseNameEn: vm.nameEn
            )
            .padding(.horizontal, 0)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    // MARK: ─ Header ──────────────────────────────────────────────────────────

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.isLoadingExercise {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 120, height: 14)
                    .shimmer()
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 32)
                    .shimmer()
            } else {
                if let category = vm.exercise?.category {
                    Text(category.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.30))
                        .kerning(1.5)
                }

                Text(vm.displayName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let error = vm.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.yellow.opacity(0.08))
                    )
                }
            }
        }
    }

    // MARK: ─ Tags ────────────────────────────────────────────────────────────

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.isLoadingExercise || vm.isEnriching {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 80, height: 32)
                    }
                }
                .shimmer()
            } else {
                if let equip = vm.equipment {
                    TagChip(text: equip, icon: "dumbbell.fill", tint: .blue)
                }
                if !vm.muscles.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(vm.muscles, id: \.self) { muscle in
                            TagChip(
                                text: muscle,
                                icon: "figure.strengthtraining.traditional",
                                tint: .green
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
    }

    // MARK: ─ Instrukce ───────────────────────────────────────────────────────

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSTRUKCE")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white.opacity(0.30))
                .kerning(1.5)

            if vm.isLoadingExercise || vm.isEnriching {
                VStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.07))
                            .frame(maxWidth: .infinity)
                            .frame(height: 14)
                    }
                }
                .shimmer()
            } else if let instructions = vm.instructions {
                Text(instructions)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            } else {
                Text("Instrukce se načítají…")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.35))
                    .italic()
            }

            // Sekundární svaly
            if !vm.secondaryMuscles.isEmpty && !vm.isEnriching {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SEKUNDÁRNĚ ZAPOJENÉ SVALY")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white.opacity(0.25))
                        .kerning(1.3)

                    FlowLayout(spacing: 6) {
                        ForEach(vm.secondaryMuscles, id: \.self) { muscle in
                            TagChip(text: muscle, icon: "dot.circle", tint: .white.opacity(0.4))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: ─ YouTube tlačítko (sekundární) ───────────────────────────────────

    @ViewBuilder
    private var youtubeButton: some View {
        if let url = vm.youtubeURL {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openURL(url)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.red.opacity(0.80))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Videotutoriál na YouTube")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("Správná technika provedení — anglicky")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.40))
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.30))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ExerciseDetailViewModel — rozšíření o gifURL
// MARK: ═══════════════════════════════════════════════════════════════════════
//
// Přidej toto rozšíření do ExerciseDetailViewModel.swift
// (nebo přímo do třídy jako computed property).
//
// Předpokládá, že ExerciseDTO nebo AIEnrichedExerciseData budou mít `gifURL: String?`
// jakmile Supabase bude toto pole obsahovat.

extension ExerciseDetailViewModel {

    /// URL GIFu pro animaci cviku.
    /// Priorita: AI enriched data → Supabase DB → nil (→ YouTube fallback).
    var gifURL: URL? {
        // 1. Zkus AI enriched data (pokud existuje `gifURLString` v AIEnrichedExerciseData)
        //    Odkomentuj jakmile bude pole přidáno do modelu:
        // if let urlString = enrichedData?.gifURL, let url = URL(string: urlString) {
        //     return url
        // }

        // 2. Zkus Supabase DB (pokud existuje `gifURL` v ExerciseDTO)
        //    Odkomentuj jakmile bude pole přidáno do Supabase tabulky:
        // if let urlString = exercise?.gifURL, let url = URL(string: urlString) {
        //     return url
        // }

        // 3. Prozatímní fallback: statický slovník pro testování
        //    Obsahuje GIF URL pro nejčastější cviky (Giphy / vlastní CDN).
        //    Nahraď vlastním CDN URL nebo Supabase storage po integraci.
        let safeSlug = exercise?.safeSlug ?? nameEn ?? ""
        return GIFLibrary.url(for: safeSlug)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: GIFLibrary  — statický slovník pro testovací GIF URL
// MARK: ═══════════════════════════════════════════════════════════════════════
//
// Temporary solution dokud Supabase bude mít gif_url sloupec.
// Nahraď vlastním CDN (např. Cloudflare R2, AWS S3, Supabase Storage).

enum GIFLibrary {

    private static let gifMap: [String: String] = [
        // Compound movements
        "barbell-bench-press":     "https://media.giphy.com/media/l46Cc8cPaJJYjNkHC/giphy.gif",
        "barbell-squat":           "https://media.giphy.com/media/3o7aDgAUIHMhHVt5aU/giphy.gif",
        "pull-up":                 "https://media.giphy.com/media/l1J9qemh1La8b0Rag/giphy.gif",
        "overhead-press":          "https://media.giphy.com/media/xT9IgmCcYOBbWnTzPq/giphy.gif",
        "romanian-deadlift":       "https://media.giphy.com/media/26uf2YTKe7HVJJXSS/giphy.gif",
        "barbell-row":             "https://media.giphy.com/media/l0HlNaQ6gWfllcjDO/giphy.gif",
        "dumbbell-bench-press":    "https://media.giphy.com/media/xTiTnt5BpRBqLvGeqA/giphy.gif",
        // Isolation
        "barbell-curl":            "https://media.giphy.com/media/3o7aDgAUIHMhHVt5aU/giphy.gif",
        "tricep-pushdown":         "https://media.giphy.com/media/l46Cc8cPaJJYjNkHC/giphy.gif",
        "lateral-raise":           "https://media.giphy.com/media/xTiTnt5BpRBqLvGeqA/giphy.gif",
        "leg-extension":           "https://media.giphy.com/media/26uf2YTKe7HVJJXSS/giphy.gif",
        "lying-leg-curl":          "https://media.giphy.com/media/l1J9qemh1La8b0Rag/giphy.gif",
        "calf-raise":              "https://media.giphy.com/media/xT9IgmCcYOBbWnTzPq/giphy.gif",
    ]

    /// Vrátí URL GIFu pro daný slug, nebo nil pokud není k dispozici.
    static func url(for slug: String) -> URL? {
        guard let urlString = gifMap[slug] else { return nil }
        return URL(string: urlString)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Preview
// MARK: ═══════════════════════════════════════════════════════════════════════

#Preview("ExerciseDetailView s médii") {
    NavigationStack {
        ExerciseDetailView(slug: "barbell-bench-press")
            .navigationTitle("Detail cviku")
    }
    .preferredColorScheme(.dark)
}

#Preview("ExerciseDetailView — YouTube fallback") {
    NavigationStack {
        ExerciseDetailView(slug: "unknown-exercise-slug")
            .navigationTitle("Detail cviku")
    }
    .preferredColorScheme(.dark)
}

// MARK: - Pomocné komponenty

struct TagChip: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.15))
        .foregroundStyle(tint)
        .clipShape(Capsule())
    }
}
