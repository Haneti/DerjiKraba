//
//  Cart.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import Foundation
import SwiftData

@Model
final class Cart {
    var id: UUID
    @Relationship(deleteRule: .cascade, inverse: \CartItem.cart)
    var items: [CartItem]?
    var createdAt: Date
    
    init(id: UUID = UUID(), createdAt: Date = Date()) {
        self.id = id
        self.items = []
        self.createdAt = createdAt
    }
    
    var totalAmount: Double {
        items?.reduce(0) { $0 + $1.totalPrice } ?? 0
    }
    
    var itemCount: Int {
        items?.count ?? 0
    }
}

@Model
final class CartItem {
    var id: UUID
    var product: Product?
    var quantity: Double
    var addedAt: Date
    @Relationship(deleteRule: .nullify)
    var cart: Cart?
    
    init(id: UUID = UUID(), product: Product? = nil, quantity: Double, addedAt: Date = Date(), cart: Cart? = nil) {
        self.id = id
        self.product = product
        self.quantity = quantity
        self.addedAt = addedAt
        self.cart = cart
    }
    
    var totalPrice: Double {
        guard let product = product else { return 0 }
        return product.pricePerKg * quantity
    }
}
