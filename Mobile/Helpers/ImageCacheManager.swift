//
//  ImageCacheManager.swift
//  DerjiKraba
//
//  Создано для реализации умного кэширования изображений
//

import Foundation
import UIKit
import CryptoKit

final class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cacheDirectory: URL
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    // Максимальный размер кэша в байтах (50 МБ)
    private let maxCacheSize: Int = 50 * 1024 * 1024
    
    private init() {
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cachesDir.appendingPathComponent("ImageCache", isDirectory: true)
        
        // Создаем директорию если не существует
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Очищаем старый кэш при запуске
        cleanupOldCache()
    }
    
    // MARK: - Публичные методы
    
    /// Получить изображение из кэша или загрузить с сервера
    /// - Parameters:
    ///   - urlString: URL изображения
    ///   - serverHash: Хэш изображения с сервера (для проверки актуальности)
    /// - Returns: Изображение (из кэша или загруженное)
    func getImage(for urlString: String, serverHash: String?) async throws -> UIImage {
        let cacheKey = urlString.md5() as NSString
        
        // Проверяем memory cache
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            print("✅ Изображение найдено в memory cache: \(urlString)")
            return cachedImage
        }
        
        // Проверяем disk cache
        let fileURL = cacheDirectory.appendingPathComponent(cacheKey as String)
        
        if let diskImage = loadImage(from: fileURL) {
            // Если есть serverHash, проверяем актуальность
            if let serverHash = serverHash {
                // Сначала пробуем прочитать хэш из файла .hash
                let storedHash = readStoredHash(for: cacheKey as String)
                
                // Если хэш не совпадает с серверным, удаляем старый кэш и загружаем новый
                if storedHash != serverHash {
                    print("⚠️ Хэши не совпадают. Сохраненный: \(storedHash ?? "nil"), Сервер: \(serverHash). Перезагружаем...")
                    try? fileManager.removeItem(at: fileURL)
                    let hashFileURL = cacheDirectory.appendingPathComponent(cacheKey as String + ".hash")
                    try? fileManager.removeItem(at: hashFileURL)
                    return try await downloadAndSaveImage(from: urlString, hash: serverHash, cacheKey: cacheKey)
                } else {
                    print("✅ Изображение найдено в disk cache, хэши совпадают: \(urlString)")
                    memoryCache.setObject(diskImage, forKey: cacheKey)
                    return diskImage
                }
            } else {
                // Если хэша нет, просто возвращаем изображение из кэша
                print("✅ Изображение найдено в disk cache (без хэша): \(urlString)")
                memoryCache.setObject(diskImage, forKey: cacheKey)
                return diskImage
            }
        }
        
        // Загружаем с сервера
        print("📥 Загрузка изображения с сервера: \(urlString)")
        return try await downloadAndSaveImage(from: urlString, hash: serverHash, cacheKey: cacheKey)
    }
    
    /// Очистить весь кэш
    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        print("🗑 Кэш очищен")
    }
    
    /// Очистить старые файлы (вызывается при запуске)
    func cleanupOldCache() {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return
        }
        
        var totalSize = 0
        var files: [(URL, Int)] = []
        
        for file in contents {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += size
                files.append((file, size))
            }
        }
        
        // Если размер превышает лимит, удаляем старые файлы
        if totalSize > maxCacheSize {
            let sortedFiles = files.sorted { file1, file2 in
                let date1 = try? file1.0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                let date2 = try? file2.0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                return date1 ?? Date() < date2 ?? Date()
            }
            
            for (file, _) in sortedFiles.prefix(sortedFiles.count / 2) {
                try? fileManager.removeItem(at: file)
                print("🗑 Удален старый файл: \(file.lastPathComponent)")
            }
        }
    }
    
    /// Получить размер кэша в МБ
    func getCacheSize() -> Double {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        let totalSize = contents.compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }.reduce(0, +)
        return Double(totalSize) / 1024.0 / 1024.0
    }
    
    // MARK: - Приватные методы
    
    private func downloadAndSaveImage(from urlString: String, hash: String?, cacheKey: NSString) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw ImageCacheError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageCacheError.downloadFailed
        }
        
        guard let image = UIImage(data: data) else {
            throw ImageCacheError.invalidImageData
        }
        
        // Сохраняем в memory cache
        memoryCache.setObject(image, forKey: cacheKey)
        
        // Сохраняем на диск
        let fileURL = cacheDirectory.appendingPathComponent(cacheKey as String)
        try? fileManager.removeItem(at: fileURL)
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            try imageData.write(to: fileURL)
            
            // Если есть хэш, сохраняем его в отдельный файл
            if let hash = hash {
                let hashFileURL = cacheDirectory.appendingPathComponent(cacheKey as String + ".hash")
                try hash.write(to: hashFileURL, atomically: true, encoding: .utf8)
                print("💾 Хэш сохранен: \(hash)")
            }
        }
        
        print("💾 Изображение сохранено в кэш: \(urlString)")
        return image
    }
    
    private func loadImage(from url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    private func calculateFileHash(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Прочитать сохраненный хэш из файла
    private func readStoredHash(for cacheKey: String) -> String? {
        let hashFileURL = cacheDirectory.appendingPathComponent(cacheKey + ".hash")
        return try? String(contentsOf: hashFileURL, encoding: .utf8)
    }
}

// MARK: - Extensions

extension String {
    func md5() -> String {
        let digest = Insecure.MD5.hash(data: data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

enum ImageCacheError: LocalizedError {
    case invalidURL
    case downloadFailed
    case invalidImageData
    case fileSystemError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL"
        case .downloadFailed: return "Ошибка загрузки"
        case .invalidImageData: return "Неверный формат изображения"
        case .fileSystemError: return "Ошибка файловой системы"
        }
    }
}
