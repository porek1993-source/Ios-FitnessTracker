import SwiftUI
import SwiftData

@MainActor
final class DataExportManager {
    static let shared = DataExportManager()
    
    private init() {}
    
    /// Vygeneruje dočasný CSV soubor se všemi tréninky a vrátí jeho URL
    func generateCSV(context: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == SessionStatus.finished.rawValue },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        
        guard let sessions = try? context.fetch(descriptor) else { return nil }
        
        var csvString = "Datum,Cvik,TypSérie,Váha_kg,Opakování\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        for session in sessions {
            let dateStr = dateFormatter.string(from: session.startedAt)
            
            for exercise in session.exercises.sorted(by: { $0.order < $1.order }) {
                let exerciseName = exercise.exerciseName.replacingOccurrences(of: ",", with: " ") // Ochrana proti rozbití CSV
                
                for set in exercise.completedSets.sorted(by: { $0.setNumber < $1.setNumber }) {
                    let typeStr = set.setTypeStr
                    let weight = set.weightKg
                    let reps = set.reps
                    
                    let row = "\(dateStr),\(exerciseName),\(typeStr),\(weight),\(reps)\n"
                    csvString.append(row)
                }
            }
        }
        
        // Uložit do tmp složky
        let fileName = "AgilniTrener_Export_\(Int(Date().timeIntervalSince1970)).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("❌ [DataExportManager] Chyba při zápisu CSV: \(error)")
            return nil
        }
    }
}

// MARK: - UI Obálka pro Tlačítko (SettingsView / ProfileView)
struct ExportButtonView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportURL: URL?
    @State private var isExporting = false
    
    var body: some View {
        VStack {
            if let url = exportURL {
                ShareLink(
                    item: url,
                    subject: Text("Můj tréninkový export"),
                    message: Text("Ahoj, posílám svá data z Agilního trenéra!"),
                    preview: SharePreview("AgilniTrener_Export.csv", image: Image(systemName: "tablecells"))
                ) {
                    Label("Sdílet CSV Export", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                Button(action: prepareExport) {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Label("Vygenerovat CSV Export", systemImage: "arrow.down.doc.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }
    
    private func prepareExport() {
        isExporting = true
        // Simulujeme lehký delay pro feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.exportURL = DataExportManager.shared.generateCSV(context: modelContext)
            self.isExporting = false
        }
    }
}
