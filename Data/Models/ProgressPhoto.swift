// ProgressPhoto.swift
// Model pro ukládání progress fotek
import Foundation
import SwiftData

@Model
final class ProgressPhoto {
    var id: UUID
    var date: Date
    @Attribute(.externalStorage) var imageData: Data
    var note: String?

    init(id: UUID = UUID(), date: Date = Date(), imageData: Data, note: String? = nil) {
        self.id = id
        self.date = date
        self.imageData = imageData
        self.note = note
    }
}
