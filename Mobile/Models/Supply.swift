//
//  Supply.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import Foundation
import SwiftData

@Model
final class Supply {
    var id: UUID
    var supplyDate: Date // Дата поставки
    var supplier: String // Название поставщика
    var totalWeight: Double // Общий вес поставки в кг
    var totalCost: Double // Общая стоимость поставки
    var notes: String // Примечания
    
    // Сотрудник, который оформил поставку
    @Relationship(deleteRule: .nullify)
    var employee: User?
    
    // Товары в поставке
    @Relationship(deleteRule: .nullify)
    var products: [Product]?
    
    init(
        id: UUID = UUID(),
        supplyDate: Date = Date(),
        supplier: String,
        totalWeight: Double,
        totalCost: Double,
        notes: String = "",
        employee: User? = nil
    ) {
        self.id = id
        self.supplyDate = supplyDate
        self.supplier = supplier
        self.totalWeight = totalWeight
        self.totalCost = totalCost
        self.notes = notes
        self.employee = employee
    }
}
