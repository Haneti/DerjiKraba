//
//  ImageAPI.swift
//  DerjiKraba
//
//  API методы для работы с изображениями
//

import Foundation
import UIKit
import CryptoKit

extension APIClient {
    
    // MARK: - Загрузка изображений товаров
    
    /// Загрузить изображение товара по URL
    /// - Parameters:
    ///   - urlString: URL изображения
    ///   - productID: ID товара (для кэширования)
    /// - Returns: Изображение и его хэш
    func downloadProductImage(from urlString: String, productID: String) async throws -> (image: UIImage, hash: String) {
        guard let url = URL(string: urlString) else {
            throw ImageAPIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageAPIError.downloadFailed
        }
        
        guard let image = UIImage(data: data) else {
            throw ImageAPIError.invalidImageData
        }
        
        // Вычисляем SHA256 хэш изображения
        let hash = calculateSHA256(of: data)
        
        return (image, hash)
    }
    
    /// Загрузить все изображения для товаров и обновить их хэши
    /// - Parameter products: Список DTO товаров
    /// - Returns: Словарь [productID: (imageURL, imageHash)]
    func fetchProductImagesMetadata(for products: [ProductDTO]) async -> [String: (url: String?, hash: String?)] {
        var result: [String: (url: String?, hash: String?)] = [:]
        
        await withTaskGroup(of: (String, String?, String?).self) { group in
            for product in products {
                guard let imageURL = product.imageURL else {
                    result[product.id] = (nil, nil)
                    continue
                }
                
                group.addTask { [weak self] in
                    do {
                        if let result = try await self?.downloadProductImage(
                            from: imageURL,
                            productID: product.id
                        ) {
                            // Сохраняем в кэш
                            _ = try? await ImageCacheManager.shared.getImage(
                                for: imageURL,
                                serverHash: result.hash
                            )
                            return (product.id, imageURL, result.hash)
                        } else {
                            return (product.id, imageURL, nil)
                        }
                    } catch {
                        print("❌ Ошибка загрузки изображения для \(product.name): \(error)")
                        return (product.id, imageURL, nil)
                    }
                }
            }
            
            for await (id, url, hash) in group {
                result[id] = (url, hash)
            }
        }
        
        return result
    }
    
    // MARK: - Вспомогательные методы
    
    private func calculateSHA256(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

enum ImageAPIError: LocalizedError {
    case invalidURL
    case downloadFailed
    case invalidImageData
    case cacheError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL изображения"
        case .downloadFailed: return "Ошибка загрузки изображения"
        case .invalidImageData: return "Некорректные данные изображения"
        case .cacheError: return "Ошибка кэширования"
        }
    }
}
