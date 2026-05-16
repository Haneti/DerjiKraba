//
//  Product.swift
//  DerjiKraba
//
//  Created by Haneti on 19.11.2025.
//

import Foundation
import SwiftData

@Model
final class Product {
    var id: UUID
    var name: String
    var category: String // Категория морепродукта (креветки, крабы, рыба и т.д.)
    /// Цена за единицу (кг или штука, в зависимости от unitType)
    var pricePerKg: Double
    /// Количество на складе в единицах (кг или штуки)
    var quantityInStock: Double
    /// Тип единицы: "kg" — весовой товар, "piece" — поштучный
    var unitType: String
    var deliveryDate: Date
    var expiryDate: Date
    var productDescription: String
    var imageURL: String?
    var imageHash: String? // Хэш изображения для проверки актуальности
    var isAvailable: Bool
    
    // Связь с поставками
    @Relationship(deleteRule: .nullify, inverse: \Supply.products)
    var supplies: [Supply]?
    
    // Связь с заказами
    @Relationship(deleteRule: .nullify)
    var orders: [Order]?
    
    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        pricePerKg: Double,
        quantityInStock: Double,
        deliveryDate: Date,
        expiryDate: Date,
        productDescription: String = "",
        imageURL: String? = nil,
        imageHash: String? = nil,
        isAvailable: Bool = true,
        unitType: String = "kg"
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.pricePerKg = pricePerKg
        self.quantityInStock = quantityInStock
        self.deliveryDate = deliveryDate
        self.expiryDate = expiryDate
        self.productDescription = productDescription
        self.imageURL = imageURL
        self.imageHash = imageHash
        self.isAvailable = isAvailable
        self.unitType = unitType
    }
    
    // Нормализованный тип единицы
    var normalizedUnitType: String {
        unitType == "piece" ? "piece" : "kg"
    }
    
    // Короткое обозначение единицы (кг / шт)
    var unitShortLabel: String {
        normalizedUnitType == "piece" ? "шт" : "кг"
    }
    
    // Форматированное количество на складе с единицей
    var formattedStockText: String {
        if normalizedUnitType == "piece" {
            return "\(Int(quantityInStock)) \(unitShortLabel)"
        } else {
            return String(format: "%.1f %@", quantityInStock, unitShortLabel)
        }
    }
    
    // Вычисляемое свойство - свежесть товара
    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
    }
    
    // Проверка, не истёк ли срок годности
    var isExpired: Bool {
        expiryDate < Date()
    }
}

// MARK: - DTO конвертация
extension ProductDTO {
    /// Конвертирует DTO в локальную SwiftData модель
    func toLocalModel(in context: ModelContext) -> Product {
        let local = Product(
            name: name,
            category: category,
            pricePerKg: pricePerKg,
            quantityInStock: quantityInStock,
            deliveryDate: deliveryDate,
            expiryDate: expiryDate,
            productDescription: description ?? "",
            imageURL: imageURL,
            imageHash: imageHash,
            isAvailable: isAvailable,
            unitType: unitType == "piece" ? "piece" : "kg"
        )
        local.id = UUID(uuidString: id) ?? UUID()
        return local
    }
}
