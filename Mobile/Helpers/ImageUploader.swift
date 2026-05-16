//
//  ImageUploader.swift
//  DerjiKraba
//
//  Утилита для загрузки изображений на сервер
//

import Foundation
import UIKit

enum ImageUploadError: LocalizedError {
    case invalidURL
    case uploadFailed
    case noImageData
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL"
        case .uploadFailed: return "Ошибка загрузки"
        case .noImageData: return "Нет данных изображения"
        case .serverError(let msg): return msg
        }
    }
}

final class ImageUploader {
    static let shared = ImageUploader()
    
    private let baseURL = "http://87.225.104.51:3000"
    
    private init() {}
    
    /// Загрузить изображение товара на сервер
    /// - Parameters:
    ///   - image: UIImage для загрузки
    ///   - productID: ID товара (UUID в формате String)
    /// - Returns: URL и хэш загруженного изображения
    func uploadProductImage(_ image: UIImage, productID: String) async throws -> (url: String, hash: String) {
        guard let url = URL(string: "\(baseURL)/products/\(productID)/image") else {
            throw ImageUploadError.invalidURL
        }
        
        // Конвертируем в JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ImageUploadError.noImageData
        }
        
        // Создаем multipart/form-data запрос
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Добавляем файл
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"product_\(productID).jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Отправляем
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? String {
                throw ImageUploadError.serverError(error)
            }
            throw ImageUploadError.uploadFailed
        }
        
        // Парсим ответ
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok = json["ok"] as? Bool, ok,
              let imageUrl = json["imageUrl"] as? String,
              let imageHash = json["imageHash"] as? String else {
            throw ImageUploadError.uploadFailed
        }
        
        print("✅ Изображение загружено: \(imageUrl)")
        return (imageUrl, imageHash)
    }
    
    /// Удалить изображение товара
    /// - Parameter productID: ID товара
    func deleteProductImage(productID: String) async throws {
        guard let url = URL(string: "\(baseURL)/products/\(productID)/image") else {
            throw ImageUploadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageUploadError.uploadFailed
        }
        
        print("✅ Изображение удалено")
    }
    
    /// Выбрать изображение из Photo Library
    /// Возвращает UIImage для последующей загрузки
    func pickImageFromLibrary() async throws -> UIImage {
        // Этот метод требует реализации через UIImagePickerController
        // Пример использования в SwiftUI:
        /*
         struct ImagePicker: UIViewControllerRepresentable {
             @Binding var selectedImage: UIImage?
             
             func makeUIViewController(context: Context) -> UIImagePickerController {
                 let picker = UIImagePickerController()
                 picker.delegate = context.coordinator
                 return picker
             }
             
             func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
             
             func makeCoordinator() -> Coordinator {
                 Coordinator(self)
             }
             
             class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
                 let parent: ImagePicker
                 
                 init(_ parent: ImagePicker) {
                     self.parent = parent
                 }
                 
                 func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                     parent.selectedImage = info[.originalImage] as? UIImage
                     picker.dismiss(animated: true)
                 }
             }
         }
         */
        fatalError("Требуется реализация через UIImagePickerController")
    }
}

// MARK: - Helper extension

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

/*
// MARK: - Пример использования в SwiftUI

struct AddProductView: View {
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    
    private func uploadImage(for product: Product) {
        guard let image = selectedImage else { return }
        
        Task {
            isUploading = true
            
            do {
                let (url, hash) = try await ImageUploader.shared.uploadProductImage(
                    image,
                    productID: product.id.uuidString
                )
                
                // Обновляем товар с новыми данными
                product.imageURL = url
                product.imageHash = hash
                
                print("✅ Загрузка завершена: \(url)")
            } catch {
                print("❌ Ошибка загрузки: \(error)")
            }
            
            isUploading = false
        }
    }
}
*/
