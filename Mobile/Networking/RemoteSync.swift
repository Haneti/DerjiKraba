//
//  RemoteSync.swift
//  DerjiKraba
//
//  Syncs remote ProductDTOs into local SwiftData Product models.
//

import Foundation
import SwiftData

func syncProductsToSwiftData(_ dtos: [ProductDTO], modelContext: ModelContext) throws {
    // Не удаляем все товары, чтобы не терять локально добавленные позиции владельцем.
    let all = FetchDescriptor<Product>()
    let existing = (try? modelContext.fetch(all)) ?? []
    var byId: [UUID: Product] = [:]
    for p in existing {
        byId[p.id] = p
    }
    
    for d in dtos {
        let remoteId = UUID(uuidString: d.id) ?? UUID()
        if let p = byId[remoteId] {
            // Обновляем поля существующего товара из удалённых данных
            p.name = d.name
            p.category = d.category
            p.pricePerKg = d.pricePerKg
            p.quantityInStock = d.quantityInStock
            p.deliveryDate = d.deliveryDate
            p.expiryDate = d.expiryDate
            p.productDescription = d.description ?? ""
            p.imageURL = d.imageURL
            p.imageHash = d.imageHash
            p.isAvailable = d.isAvailable
            p.unitType = d.unitType
        } else {
            // Новый товар, пришедший с сервера
            let p = Product(
                id: remoteId,
                name: d.name,
                category: d.category,
                pricePerKg: d.pricePerKg,
                quantityInStock: d.quantityInStock,
                deliveryDate: d.deliveryDate,
                expiryDate: d.expiryDate,
                productDescription: d.description ?? "",
                imageURL: d.imageURL,
                imageHash: d.imageHash,
                isAvailable: d.isAvailable,
                unitType: d.unitType
            )
            modelContext.insert(p)
        }
    }
    
    try modelContext.save()
}
