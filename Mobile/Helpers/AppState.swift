//
//  AppState.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import Foundation
import SwiftUI
import SwiftData

@Observable
class AppState {
    private let sessionKey = "currentUserPhone"

    var currentUser: User?
    var cartItems: [CartItem] = []
    var isShowingAuth = false
    
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    var isEmployee: Bool {
        // Считаем владельца сотрудником для доступа к админ-вкладкам
        if let role = currentUser?.role {
            return role == .employee || role == .owner
        }
        return false
    }
    
    var isClient: Bool {
        currentUser?.role == .client
    }
    
    func login(user: User) {
        self.currentUser = user
        self.isShowingAuth = false
        // Сохраняем сессию
        UserDefaults.standard.set(user.phone, forKey: sessionKey)
    }
    
    func logout() {
        self.currentUser = nil
        self.cartItems.removeAll()
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
    
    func restoreSession(modelContext: ModelContext) {
        guard let phone = UserDefaults.standard.string(forKey: sessionKey) else { return }
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.phone == phone }
        )
        if let user = try? modelContext.fetch(descriptor).first {
            self.currentUser = user
        }
    }

    func ensureOwnerExists(modelContext: ModelContext) {
        let ownerPhone = "79841752998" // +7 (984) 175-29-98
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.phone == ownerPhone }
        )
        if let count = try? modelContext.fetchCount(descriptor), count == 0 {
            let owner = User(
                phone: ownerPhone,
                firstName: "Артем",
                lastName: "Никитин",
                middleName: "Русланович",
                role: .owner,
                isVerified: true
            )
            modelContext.insert(owner)
            try? modelContext.save()
        }
    }
    
    func addToCart(product: Product, quantity: Double) {
        // Максимум 10 кг на товар и не больше остатка на складе
        let cap = min(10.0, product.quantityInStock)
        if let index = cartItems.firstIndex(where: { $0.product?.id == product.id }) {
            let current = cartItems[index].quantity
            let newQuantity = min(current + quantity, cap)
            cartItems[index].quantity = newQuantity
        } else {
            let initialQuantity = min(quantity, cap)
            guard initialQuantity > 0 else { return }
            let item = CartItem(product: product, quantity: initialQuantity)
            cartItems.append(item)
        }
    }
    
    func removeFromCart(item: CartItem) {
        cartItems.removeAll { $0.id == item.id }
    }
    
    func clearCart() {
        cartItems.removeAll()
    }
    
    var cartTotal: Double {
        cartItems.reduce(0) { $0 + $1.totalPrice }
    }
    
    var cartItemCount: Int {
        cartItems.count
    }
}
