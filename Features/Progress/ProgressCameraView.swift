// ProgressCameraView.swift
// Focení progressu s overlayem předchozí fotky pro dodržení konzistence úhlů

import SwiftUI
import SwiftData
import AVFoundation

struct ProgressGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]
    
    @State private var showCamera = false
    @State private var selectedPhoto: ProgressPhoto?
    
    // Sloupce pro mřížku
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if photos.isEmpty {
                    EmptyStateView(
                        icon: "camera.viewfinder",
                        title: "Zatím žádné fotky",
                        message: "Tady uvidíš svůj vizuální progress. Vyfoť se hned teď a začni!",
                        iconColor: .orange.opacity(0.8)
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photos) { photo in
                                if let uiImage = UIImage(data: photo.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .onTapGesture {
                                            selectedPhoto = photo
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Moje Fotky")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCamera = true }) {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ProgressCameraView(previousPhotoData: photos.first?.imageData)
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Detail Fotky
struct PhotoDetailView: View {
    let photo: ProgressPhoto
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
                
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Text(photo.date.formatted(date: .long, time: .shortened))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zavřít") { dismiss() }.foregroundStyle(.orange)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog("Opravdu vymazat?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Vymazat fotku", role: .destructive) {
                    modelContext.delete(photo)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Kamera View s ImagePickerem (UIKit wrapper)
struct ProgressCameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var previousPhotoData: Data?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        
        // Zkus použít kameru
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraDevice = .front
            picker.showsCameraControls = true
            
            // Přidáme overlay
            if let data = previousPhotoData, let previousImage = UIImage(data: data) {
                let overlayView = UIImageView(image: previousImage)
                overlayView.alpha = 0.35 // 35 % neprůhlednost overlaye
                overlayView.contentMode = .scaleAspectFill
                
                // Uděláme overlay velký přesně jako celá obrazovka (kamera preview)
                let screenSize = UIScreen.main.bounds
                overlayView.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)
                
                // Maska nahoře i dole aby nekolidovalo s tlačítky UIImagePickerControlleru
                picker.cameraOverlayView = overlayView
            }
        } else {
            // Fallback na galerii (simulátor)
            picker.sourceType = .photoLibrary
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ProgressCameraView
        
        init(_ parent: ProgressCameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Resize image pro optimalizaci (nedržíme raw data z foťáku)
                if let data = image.jpegData(compressionQuality: 0.8) {
                    let newPhoto = ProgressPhoto(imageData: data)
                    parent.modelContext.insert(newPhoto)
                }
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
