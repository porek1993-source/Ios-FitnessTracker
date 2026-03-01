// WorkoutSetRowView.swift
// Agilní Fitness Trenér — Refaktorovaný řádek pro sérii
// Obohaceno o přímý RPE Picker a volání HapticManageru

import SwiftUI

struct WorkoutSetRowView: View {
    let setNumber:  Int
    @Binding var currentSet: SetState
    let isActive:   Bool
    let onComplete: () -> Void

    @FocusState private var wFocus: Bool
    @FocusState private var rFocus: Bool

    @State private var weightText = ""
    @State private var repsText   = ""
    @State private var bounce:    CGFloat = 1
    
    // RPE State
    @State private var showRPEPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {

                // ① Badge (Klikací pro změnu typu série)
                SetBadge(number: setNumber, isCompleted: currentSet.isCompleted, isActive: isActive, type: currentSet.type)
                    .frame(width: 38)
                    .onTapGesture {
                        if isActive && !currentSet.isCompleted {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation {
                                currentSet.type = currentSet.type.next
                            }
                        }
                    }

                // ② Weight
                InlineField(
                    text:        $weightText,
                    hint:        previousWeightHint,
                    suffix:      "kg",
                    keyboard:    .decimalPad,
                    isFocused:   _wFocus,
                    isActive:    isActive,
                    isCompleted: currentSet.isCompleted
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
                .onChange(of: weightText) { _, v in
                    currentSet.weightKg = Double(v.replacingOccurrences(of: ",", with: "."))
                }

                // ③ Reps
                InlineField(
                    text:        $repsText,
                    hint:        "\(currentSet.targetRepsMin)–\(currentSet.targetRepsMax)",
                    suffix:      nil,
                    keyboard:    .numberPad,
                    isFocused:   _rFocus,
                    isActive:    isActive,
                    isCompleted: currentSet.isCompleted
                )
                .frame(width: 66)
                .padding(.horizontal, 4)
                .onChange(of: repsText) { _, v in currentSet.reps = Int(v) }

                // ④ RPE Tlačítko
                RPEATriggerCell(value: $currentSet.rpe, isActive: isActive, isCompleted: currentSet.isCompleted)
                    .frame(width: 52)
                    .onTapGesture {
                        if isActive && !currentSet.isCompleted {
                            withAnimation(.easeInOut) { showRPEPicker.toggle() }
                        }
                    }

                // ⑤ Complete
                CompleteButton(
                    canComplete: canComplete,
                    isActive:    isActive,
                    isCompleted: currentSet.isCompleted,
                    bounce:      bounce,
                    action:      handleComplete
                )
                .frame(width: 48)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            
            // Zobrazení in-place RPE Pickeru hned pod řádkem série
            if showRPEPicker {
                InlineRPEPicker(selectedRPE: $currentSet.rpe, onSelect: { showRPEPicker = false })
                    .padding(.bottom, 8)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Minulý výkon u série
            if let histW = currentSet.historicalWeightKg, let histR = currentSet.historicalReps, !currentSet.isCompleted, isActive {
                let wStr = histW.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", histW) : String(format: "%.1f", histW)
                HStack {
                    Text("Minule: \(wStr)kg × \(histR)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
                .padding(.top, -4)
            }
        }
        .background(enhancedRowBackground)
        .opacity(rowOpacity)
        .animation(.easeInOut(duration: 0.18), value: isActive)
        .animation(.easeInOut(duration: 0.18), value: currentSet.isCompleted)
        .onAppear {
            if let prev = currentSet.previousWeightKg {
                weightText   = prev.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", prev) : String(format: "%.1f", prev)
                currentSet.weightKg = prev
            }
            // Zobrazit RPE pokud je série aktivní a ještě není vyplněné
            if isActive && currentSet.rpe == nil && !currentSet.isWarmup {
                // Může se rovnou otevírat, ale raději to necháme na uživateli
            }
        }
    }

    private var previousWeightHint: String {
        guard let prev = currentSet.previousWeightKg else { return "—" }
        return prev.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", prev) : String(format: "%.1f", prev)
    }

    private var isBodyweight: Bool { currentSet.previousWeightKg == nil && currentSet.weightKg == nil }
    private var canComplete: Bool { currentSet.reps != nil && (isBodyweight || currentSet.weightKg != nil) }

    private func handleComplete() {
        withAnimation(.spring(response: 0.12, dampingFraction: 0.45)) { bounce = 0.80 }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55).delay(0.1)) { bounce = 1.0 }
        
        // Globální haptická odezva! ✅
        HapticManager.shared.setCompleted()
        
        onComplete()
    }

    private var enhancedRowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isActive
                   ? Color(red: 0.14, green: 0.14, blue: 0.20)
                   : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isActive
                            ? AppColors.primaryAccent.opacity(0.6)
                            : Color.clear,
                        lineWidth: isActive ? 1.5 : 0
                    )
            )
            .shadow(
                color: isActive ? AppColors.primaryAccent.opacity(0.15) : .clear,
                radius: 8, x: 0, y: 0
            )
    }

    private var rowOpacity: Double {
        if currentSet.isCompleted { return 0.85 }
        return isActive ? 1.0 : 0.45
    }
}

// MARK: - Inline RPE Picker

private struct InlineRPEPicker: View {
    @Binding var selectedRPE: Int?
    let onSelect: () -> Void
    
    let rpeValues = [6, 7, 8, 9, 10]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Subjektivní náročnost (RPE)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.leading, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(rpeValues, id: \.self) { val in
                        Button {
                            selectedRPE = val
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSelect()
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(val)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(selectedRPE == val ? .white : .white.opacity(0.6))
                                Text(val == 10 ? "Selhání" : "RIR \(10 - val)")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(selectedRPE == val ? .white.opacity(0.8) : .white.opacity(0.4))
                            }
                            .frame(width: 50, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selectedRPE == val ? Color.blue : Color.white.opacity(0.08))
                            )
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Sub-views copied from ActiveSessionView

private struct SetBadge: View {
    let number: Int; let isCompleted: Bool; let isActive: Bool; let type: SetType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(bgColor)
                .frame(width: 30, height: 30)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.black)
            } else {
                Text(type == .normal ? "\(number)" : type.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.32))
            }
        }
        .animation(.spring(response: 0.22), value: isCompleted)
    }

    private var bgColor: Color {
        if isCompleted { return Color(red:0.13, green:0.80, blue:0.43) }
        
        // Zvýraznění aktivní série barevně (pouze pokud není .normal, ta je šedá/bílá)
        if isActive && type != .normal { return type.color.opacity(0.4) }
        if isActive { return .white.opacity(0.14) }
        
        // Neaktivní série s typem
        if type != .normal { return type.color.opacity(0.15) }
        return .white.opacity(0.05)
    }
}

private struct InlineField: View {
    @Binding var text: String
    let hint: String; let suffix: String?
    let keyboard: UIKeyboardType
    @FocusState var isFocused: Bool
    let isActive: Bool; let isCompleted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fieldBg)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocused ? Color.blue.opacity(0.65) : Color.clear, lineWidth: 1.5))

            if text.isEmpty && !isFocused {
                Text(hint)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.20))
            }

            HStack(spacing: 2) {
                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .focused($isFocused)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .disabled(!isActive || isCompleted)
                if let s = suffix, !text.isEmpty {
                    Text(s).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.28))
                }
            }
        }
        .frame(height: 52)
    }

    private var fieldBg: Color {
        if isFocused { return .white.opacity(0.10) }
        return isActive ? .white.opacity(0.07) : .clear
    }
}

private struct RPEATriggerCell: View {
    @Binding var value: Int?
    let isActive: Bool; let isCompleted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? .white.opacity(0.07) : .clear)
            if let val = value {
                Text("@\(val)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(isCompleted ? .white.opacity(0.6) : .white)
            } else {
                Text("—")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.20))
            }
        }
        .frame(height: 52)
    }
}

private struct CompleteButton: View {
    let canComplete: Bool
    let isActive: Bool
    let isCompleted: Bool
    let bounce: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(bgColor)
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 52)
        .disabled(!canComplete && !isCompleted)
        .opacity(btnOpacity)
        .scaleEffect(bounce)
    }

    private var bgColor: Color {
        if isCompleted { return Color.white.opacity(0.10) }
        return canComplete ? Color(red:0.15, green:0.82, blue:0.45) : .white.opacity(0.06)
    }
    private var btnOpacity: Double {
        if isCompleted { return 0.5 }
        if !isActive   { return 0.2 }
        return canComplete ? 1.0 : 0.4
    }
}
