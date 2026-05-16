//
//  CachedAsyncImageView.swift
//  DerjiKraba
//
//  Компонент для отображения изображений с кэшированием
//

import SwiftUI

struct CachedAsyncImageView: View {
    let imageURL: String?
    let placeholderName: String?
    let imageHash: String?
    let contentMode: ContentMode
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(imageURL: String?, placeholderName: String? = nil, imageHash: String? = nil, contentMode: ContentMode = .fill) {
        self.imageURL = imageURL
        self.placeholderName = placeholderName
        self.imageHash = imageHash
        self.contentMode = contentMode
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else if let placeholderName = placeholderName,
                      let placeholderImage = UIImage(named: placeholderName) {
                Image(uiImage: placeholderImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            }
        }
        .task {
            await loadImage()
        }
        .onChange(of: imageURL) { _, _ in
            Task {
                await loadImage()
            }
        }
    }
    
    @MainActor
    private func loadImage() async {
        guard let urlString = imageURL else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedImage = try await ImageCacheManager.shared.getImage(
                for: urlString,
                serverHash: imageHash
            )
            self.image = loadedImage
        } catch {
            self.errorMessage = error.localizedDescription
            print("❌ Ошибка загрузки изображения: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    VStack(spacing: 20) {
        // Пример с URL
        CachedAsyncImageView(
            imageURL: "https://via.placeholder.com/150",
            placeholderName: nil
        )
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        
        // Пример с placeholder из Assets
        CachedAsyncImageView(
            imageURL: nil,
            placeholderName: "Камчатский краб"
        )
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}
