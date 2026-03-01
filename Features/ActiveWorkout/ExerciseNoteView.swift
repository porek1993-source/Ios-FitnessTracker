import SwiftUI
import SwiftData

struct ExerciseNoteView: View {
    let slug: String
    @Environment(\.modelContext) private var modelContext
    @State private var text: String = ""
    @State private var isEditing: Bool = false
    @State private var loadedNote: ExerciseNote?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35)) { isEditing.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(text.isEmpty ? .white.opacity(0.4) : .yellow)
                        .font(.system(size: 14))
                    
                    Text(text.isEmpty ? "Přidat poznámku (např. pozice sedačky)" : "Poznámka ke cviku")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(text.isEmpty ? .white.opacity(0.6) : .white)
                    
                    Spacer()
                    
                    Image(systemName: isEditing ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if isEditing {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Např. Opěradlo na číslo 3, lanko dole...")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.25))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }
                    
                    TextEditor(text: $text)
                        .frame(minHeight: 70)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .font(.system(size: 14))
                        .onChange(of: text) { _, newVal in
                            debouncedSave(newVal)
                        }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            loadNote()
        }
    }

    @State private var saveTask: Task<Void, Never>?

    private func debouncedSave(_ newText: String) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            guard !Task.isCancelled else { return }
            saveNote(newText)
        }
    }

    private func loadNote() {
        let slugToSearch = slug
        let descriptor = FetchDescriptor<ExerciseNote>(predicate: #Predicate { $0.exerciseSlug == slugToSearch })
        if let found = try? modelContext.fetch(descriptor).first {
            loadedNote = found
            text = found.note
        }
    }

    private func saveNote(_ newText: String) {
        if let existing = loadedNote {
            existing.note = newText
            existing.updatedAt = .now
        } else {
            let fresh = ExerciseNote(exerciseSlug: slug, note: newText)
            modelContext.insert(fresh)
            loadedNote = fresh
            try? modelContext.save()
        }
    }
}
