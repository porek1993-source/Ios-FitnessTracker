// SetControlViews.swift
import SwiftUI

// MARK: - Set Header

struct SetHeaderRow: View {
    @State private var showLegend = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text("SET").frame(width: 36, alignment: .leading)
                Button {
                    withAnimation(.spring(response: 0.3)) { showLegend.toggle() }
                } label: {
                    Image(systemName: showLegend ? "info.circle.fill" : "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            Text("KG").frame(maxWidth: .infinity)
            Text("REPS").frame(maxWidth: .infinity)
            Text("RPE").frame(width: 52)
            Spacer().frame(width: 44)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.white.opacity(0.35))
        .kerning(1.2)
        .padding(.horizontal, 4)

        if showLegend {
            SetTypeLegendView()
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Set Type Legend

struct SetTypeLegendView: View {
    private let items: [(String, Color, String)] = [
        ("W", .cyan,   "Zahřívací série — lehká váha, zahřátí svalů a kloubů"),
        ("N", .white,  "Pracovní série — hlavní tréninková zátěž (working set)"),
        ("D", .orange, "Drop set — snížení váhy bez pauzy, pokračuj do únavy"),
        ("F", .red,    "Série do selhání — maximální intenzita, poslední rep nelze dokončit")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.0) { abbr, color, desc in
                HStack(alignment: .top, spacing: 10) {
                    Text(abbr)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(color)
                        .frame(width: 14, alignment: .leading)
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

// MARK: - Set Row

struct SetRowView: View {
    let setNumber: Int
    @Binding var setData: SetState
    let isActive: Bool
    let onComplete: () -> Void

    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    // Doporučená váha (midpoint targetReps pro rychlé předvyplnění)
    private var suggestedReps: Int {
        (setData.targetRepsMin + setData.targetRepsMax) / 2
    }

    var body: some View {
        HStack(spacing: 8) {
            // ── Číslo/typ série ──────────────────────
            ZStack {
                Circle()
                    .fill(setData.isCompleted
                          ? Color.green.opacity(0.25)
                          : (isActive ? Color.white.opacity(0.12) : Color.white.opacity(0.05)))
                    .frame(width: 32, height: 32)
                if setData.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    // Zobrazit typ série zkratkou (W/N/D/F) s barvou
                    Text(setTypeLabel)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(setTypeColor)
                }
            }
            .frame(width: 36)

            // ── Váha ─────────────────────────────────
            CompactNumberField(
                value: Binding(
                    get: { setData.weightKg },
                    set: { setData.weightKg = $0 ?? 0 }
                ),
                placeholder: setData.previousWeightKg.map { String(format: "%.1f", $0) } ?? "—",
                isFocused: _weightFocused,
                isActive: isActive,
                isCompleted: setData.isCompleted
            )
            .frame(maxWidth: .infinity)
            .onChange(of: weightFocused) { _, focused in
                // Auto-fill předchozí váhu při prvním klepnutí (pokud je pole prázdné)
                if focused && (setData.weightKg == 0), let prev = setData.previousWeightKg {
                    setData.weightKg = prev
                }
            }

            // ── Reps ──────────────────────────────────
            CompactIntField(
                value: Binding(
                    get: { setData.reps },
                    set: { setData.reps = $0 }
                ),
                placeholder: "\(setData.targetRepsMin)–\(setData.targetRepsMax)",
                isFocused: _repsFocused,
                isActive: isActive,
                isCompleted: setData.isCompleted
            )
            .frame(maxWidth: .infinity)

            // ── RPE ───────────────────────────────────
            RPEPicker(
                value: Binding(
                    get: { setData.rpe },
                    set: { setData.rpe = $0 }
                ),
                isActive: isActive,
                isCompleted: setData.isCompleted
            )
            .frame(width: 52)

            // ── Rychlé dokončení ──────────────────────
            Button {
                // Pokud ještě nejsou reps vyplněny, předvyplníme midpoint a hned dokončíme
                if setData.reps == nil { setData.reps = suggestedReps }
                // Pokud váha není, předvyplníme z historii
                if setData.weightKg == 0, let prev = setData.previousWeightKg {
                    setData.weightKg = prev
                }
                onComplete()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? (setData.isCompleted ? Color.green.opacity(0.15) : Color.green.opacity(0.8)) : Color.clear)
                        .frame(width: 44, height: 40)
                    Image(systemName: setData.isCompleted ? "checkmark.circle.fill" : "checkmark")
                        .font(.system(size: setData.isCompleted ? 20 : 16, weight: .semibold))
                        .foregroundStyle(setData.isCompleted ? .green : (isActive ? .white : .white.opacity(0.2)))
                }
            }
            .disabled(!isActive && !setData.isCompleted)
            .animation(.spring(response: 0.25), value: setData.isCompleted)
            .accessibilityLabel(setData.isCompleted ? "Série \(setNumber) dokončena" : "Dokončit sérii \(setNumber)")
            .accessibilityHint("Klepni pro rychlé zaznamenání série")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .opacity(setData.isCompleted ? 0.6 : (isActive ? 1.0 : 0.45))
        .animation(.easeInOut(duration: 0.2), value: isActive)
        // Předvyplnění váhy a repů při aktivaci série
        .onAppear {
            guard isActive, !setData.isCompleted else { return }
            if setData.weightKg == 0, let prev = setData.previousWeightKg {
                setData.weightKg = prev
            }
            if setData.reps == nil {
                setData.reps = suggestedReps
            }
        }
    }

    // MARK: - Set type display
    private var setTypeLabel: String {
        switch setData.type {
        case .warmup:  return "W"
        case .normal:  return "N"
        case .dropset: return "D"
        case .failure: return "F"
        }
    }

    private var setTypeColor: Color {
        switch setData.type {
        case .warmup:  return .cyan
        case .normal:  return .white
        case .dropset: return .orange
        case .failure: return .red
        }
    }

    // MUSÍ odpovídat guardu v WorkoutViewModel.completeSet()!
    private var canComplete: Bool { setData.reps != nil }
}

// MARK: - Number Fields

struct CompactNumberField: View {
    @Binding var value: Double?
    let placeholder: String
    @FocusState var isFocused: Bool
    let isActive: Bool
    let isCompleted: Bool
    @State private var text = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isFocused ? Color.white.opacity(0.12) : (isActive ? Color.white.opacity(0.07) : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isFocused ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 1.5))
            if text.isEmpty && !isFocused {
                Text(placeholder)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            }
            TextField("", text: $text)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .onChange(of: text) { _, v in
                    value = Double(v.replacingOccurrences(of: ",", with: "."))
                }
                .onChange(of: value) { _, v in
                    // Sync external changes back to text (e.g. previous weight loaded)
                    if !isFocused, let v {
                        let formatted = v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
                        if text != formatted { text = formatted }
                    } else if !isFocused && v == nil && !text.isEmpty {
                        // Value cleared externally
                        text = ""
                    }
                }
        }
        .frame(height: 42)
        .disabled(!isActive || isCompleted)
    }
}

struct CompactIntField: View {
    @Binding var value: Int?
    let placeholder: String
    @FocusState var isFocused: Bool
    let isActive: Bool
    let isCompleted: Bool
    @State private var text = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isFocused ? Color.white.opacity(0.12) : (isActive ? Color.white.opacity(0.07) : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isFocused ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 1.5))
            if text.isEmpty && !isFocused {
                Text(placeholder)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            }
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .onChange(of: text) { _, v in value = Int(v) }
                .onChange(of: value) { _, v in
                    if !isFocused {
                        let newText = v.map { "\($0)" } ?? ""
                        if text != newText { text = newText }
                    }
                }
        }
        .frame(height: 42)
        .disabled(!isActive || isCompleted)
    }
}

// MARK: - RPE Picker

struct RPEPicker: View {
    @Binding var value: Int?
    let isActive: Bool
    let isCompleted: Bool
    @State private var showPicker = false

    var body: some View {
        Button { guard isActive && !isCompleted else { return }; showPicker = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive && !isCompleted ? Color.white.opacity(0.07) : Color.clear)
                VStack(spacing: 1) {
                    if let v = value {
                        Text("\(v)").font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundStyle(rpeColor(v))
                        Text("RPE").font(.system(size: 8, weight: .semibold)).foregroundStyle(.white.opacity(0.35))
                    } else {
                        Text("—").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white.opacity(0.25))
                        Text("RPE").font(.system(size: 8, weight: .semibold)).foregroundStyle(.white.opacity(0.2))
                    }
                }
            }
            .frame(width: 52, height: 42)
        }
        .sheet(isPresented: $showPicker) {
            RPEPickerSheet(value: $value).presentationDetents([.height(320)])
        }
    }

    private func rpeColor(_ v: Int) -> Color {
        Color.rpeColor(for: v)
    }
}

struct RPEPickerSheet: View {
    @Binding var value: Int?
    @Environment(\.dismiss) private var dismiss
    private let labels = [
        1: "Velmi lehce", 2: "Lehce", 3: "Mírně", 4: "Trochu snaha", 5: "Střední",
        6: "Náročné", 7: "Těžké", 8: "Velmi těžké", 9: "Maximální", 10: "Absolutní max"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Jak těžká byla série?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 20)
            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(1...10, id: \.self) { i in
                    Button {
                        value = i
                        dismiss()
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(i)").font(.system(size: 22, weight: .bold))
                            Text(labels[i] ?? "").font(.system(size: 9)).multilineTextAlignment(.center).lineLimit(2)
                        }
                        .foregroundStyle(value == i ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(value == i ? rpeColor(i) : Color.white.opacity(0.1)))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(white: 0.1).ignoresSafeArea())
    }

    private func rpeColor(_ v: Int) -> Color {
        Color.rpeColor(for: v)
    }
}
