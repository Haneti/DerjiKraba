//
//  Order.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import Foundation
import SwiftData

enum OrderStatus: String, Codable {
    case pending = "Ожидает обработки"
    case processing = "В обработке"
    case ready = "Готов к выдаче"
    case delivering = "Доставляется"
    case completed = "Выполнен"
    case cancelled = "Отменен"
}

enum DeliveryType: String, Codable {
    case pickup = "Самовывоз"
    case delivery = "Доставка"
}

@Model
final class Order {
    var id: UUID
    var orderDate: Date
    var status: OrderStatus
    var deliveryType: DeliveryType
    var deliveryAddress: String?
    var totalAmount: Double // Общая сумма заказа
    var notes: String // Примечания к заказу
    
    // Клиент, оформивший заказ
    @Relationship(deleteRule: .nullify)
    var customer: User?
    
    // Товары в заказе
    @Relationship(deleteRule: .nullify)
    var products: [Product]?
    
    // Позиции заказа с количеством
    @Relationship(deleteRule: .cascade, inverse: \OrderItem.order)
    var items: [OrderItem]?
    
    init(
        id: UUID = UUID(),
        orderDate: Date = Date(),
        status: OrderStatus = .pending,
        deliveryType: DeliveryType,
        deliveryAddress: String? = nil,
        totalAmount: Double = 0,
        notes: String = "",
        customer: User? = nil
    ) {
        self.id = id
        self.orderDate = orderDate
        self.status = status
        self.deliveryType = deliveryType
        self.deliveryAddress = deliveryAddress
        self.totalAmount = totalAmount
        self.notes = notes
        self.customer = customer
    }
}

// Отдельная модель для позиций заказа (товар + количество)
@Model
final class OrderItem {
    var id: UUID
    var product: Product?
    var quantity: Double // Количество в кг
    var pricePerKg: Double // Цена на момент заказа
    
    @Relationship(deleteRule: .nullify)
    var order: Order?
    
    init(
        id: UUID = UUID(),
        product: Product? = nil,
        quantity: Double,
        pricePerKg: Double
    ) {
        self.id = id
        self.product = product
        self.quantity = quantity
        self.pricePerKg = pricePerKg
    }
    
    var totalPrice: Double {
        quantity * pricePerKg
    }
}
