//
//  Inventory.swift
//  DerjiKraba
//
//  Created for inventory management and stock adjustments
//

import Foundation
import SwiftData

@Model
final class InventoryAdjustment {
    var id: UUID
    var productId: UUID
    var productName: String
    var systemQuantity: Double // Количество по системе
    var actualQuantity: Double // Количество после пересчета
    var difference: Double // Разница (actual - system)
    var adjustmentType: AdjustmentType
    var reason: String?
    var performedBy: UUID // ID сотрудника
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        productId: UUID,
        productName: String,
        systemQuantity: Double,
        actualQuantity: Double,
        adjustmentType: AdjustmentType,
        reason: String? = nil,
        performedBy: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.systemQuantity = systemQuantity
        self.actualQuantity = actualQuantity
        self.difference = actualQuantity - systemQuantity
        self.adjustmentType = adjustmentType
        self.reason = reason
        self.performedBy = performedBy
        self.createdAt = createdAt
    }
    
    var hasShortage: Bool {
        difference < 0
    }
    
    var hasSurplus: Bool {
        difference > 0
    }
}

enum AdjustmentType: String, Codable {
    case shortage = "Недостача"
    case surplus = "Излишек"
    case writeOff = "Списание"
    case adjustment = "Корректировка"
}

// Модель для отображения результатов инвентаризации
struct InventoryReport {
    let product: Product
    let systemQuantity: Double
    let actualQuantity: Double
    let difference: Double
    let adjustmentType: AdjustmentType
    
    var isProblematic: Bool {
        abs(difference) > 0.01 // Небольшая погрешность допускается
    }
}
