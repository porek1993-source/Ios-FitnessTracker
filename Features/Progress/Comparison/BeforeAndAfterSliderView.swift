// BeforeAndAfterSliderView.swift
// Draggable slider to compare two photos

import SwiftUI

struct BeforeAndAfterSliderView: View {
    let beforeImage: UIImage
    let afterImage: UIImage
    
    @State private var dragOffset: CGFloat = 0.5 // 0.0 to 1.0 (center)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // Bottom Image (Before)
                    Image(uiImage: beforeImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay(alignment: .topLeading) {
                            labelTag("PŘED")
                        }
                    
                    // Top Image (After) with Mask
                    Image(uiImage: afterImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .mask(
                            HStack {
                                Rectangle()
                                    .frame(width: geo.size.width * dragOffset)
                                Spacer(minLength: 0)
                            }
                        )
                        .overlay(alignment: .topTrailing) {
                            labelTag("POTÉ")
                        }
                    
                    // Draggable Vertical Handle
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 4)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                                .shadow(radius: 4)
                                .overlay(
                                    Image(systemName: "arrow.left.and.right")
                                        .foregroundStyle(.black)
                                        .font(.system(size: 16, weight: .bold))
                                )
                        )
                        .position(x: geo.size.width * dragOffset, y: geo.size.height / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newOffset = value.location.x / geo.size.width
                                    dragOffset = min(max(newOffset, 0), 1)
                                }
                        )
                }
            }
            .navigationTitle("Porovnání")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zavřít") { dismiss() }.foregroundStyle(.orange)
                }
            }
        }
    }
    
    private func labelTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .black))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.black.opacity(0.6))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(16)
    }
}
