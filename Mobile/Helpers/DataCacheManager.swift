//
//  DataCacheManager.swift
//  DerjiKraba
//
//  Manager for caching and auto-refreshing data
//

import Foundation
import SwiftUI

@Observable
class DataCacheManager {
    static let shared = DataCacheManager()
    
    // Кэш продуктов
    private var productsCache: [ProductDTO]?
    private var productsLastFetch: Date?
    
    // Кэш заказов
    private var ordersCache: [OrderDTO]?
    private var ordersLastFetch: Date?
    
    // Таймер авто-обновления
    private var autoRefreshTimer: Timer?
    
    // Подписчики на обновления
    var onOrdersUpdated: (() -> Void)?
    var onProductsUpdated: (() -> Void)?
    var appState: AppState?

    private init() {
        startAutoRefresh()
    }
    
    // MARK: - Products Cache
    
    func getProducts(forceRefresh: Bool = false) async throws -> [ProductDTO] {
        // Проверяем кэш
        if !forceRefresh,
           let cached = productsCache,
           let lastFetch = productsLastFetch,
           Date().timeIntervalSince(lastFetch) < 300 { // 5 минут
            return cached
        }
        
        // Загружаем с сервера
        let api = await MainActor.run {
            APIClient(baseURL: URL(string: "https://derji-kraba.ru/api")!)
        }
        let products = try await api.fetchProducts()
        
        // Обновляем кэш
        self.productsCache = products
        self.productsLastFetch = Date()
        
        return products
    }
    
    func clearProductsCache() {
        productsCache = nil
        productsLastFetch = nil
    }
    
    // MARK: - Orders Cache
    
    func getOrders(forceRefresh: Bool = false) async throws -> [OrderDTO] {
        // Проверяем кэш
        if !forceRefresh,
           let cached = ordersCache,
           let lastFetch = ordersLastFetch,
           Date().timeIntervalSince(lastFetch) < 60 { // 1 минута
            return cached
        }
        
        // Загружаем с сервера
        let api = APIClient()
        let orders = try await api.fetchOrders()
        
        // Обновляем кэш
        self.ordersCache = orders
        self.ordersLastFetch = Date()
        
        return orders
    }
    
    func getOrders(forUser userId: String, forceRefresh: Bool = false) async throws -> [OrderDTO] {
        // Для пользовательских заказов не используем долгий кэш
        if !forceRefresh,
           let cached = ordersCache,
           let lastFetch = ordersLastFetch,
           Date().timeIntervalSince(lastFetch) < 30 { // 30 секунд
            return cached.filter { $0.userId == userId }
        }
        
        // Загружаем с сервера
        let api = APIClient()
        let orders = try await api.fetchOrders(forUser: userId)
        
        // Обновляем кэш
        self.ordersCache = orders
        self.ordersLastFetch = Date()
        
        return orders
    }
    
    func clearOrdersCache() {
        ordersCache = nil
        ordersLastFetch = nil
    }
    
    // MARK: - Auto Refresh
    
    private func startAutoRefresh() {
    Task {
        while true {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            await autoRefreshData()
            }
        }
    }
    
    private func autoRefreshData() async {
    guard let appState = appState else { return }

    if appState.currentUser != nil {
        do {
            let api = APIClient()
            let newOrders = try await api.fetchOrders()

            let oldCount = ordersCache?.count ?? 0
            if newOrders.count != oldCount {
                ordersCache = newOrders
                ordersLastFetch = Date()
                onOrdersUpdated?()
            }
        } catch {
            print("Auto refresh error:", error)
        }
    }
}
    
    // MARK: - Real-time Chat Updates
    
    func startChatUpdates(clientPhone: String, onUpdate: @escaping ([SupportMessageDTO]) -> Void) {
        // Опрос каждые 5 секунд для чата
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                do {
                    let api = await MainActor.run {
                        APIClient()
                    }
                    let messages = try await api.fetchSupportMessages(phone: clientPhone)
                    await MainActor.run {
                        onUpdate(messages)
                    }
                } catch {
                    // Тихая ошибка
                }
            }
        }
    }
}

// Helper для поиска AppState
extension UIViewController {
    func viewControllerWithAppState() -> AppState? {
        if let window = self.view.window {
            var responder: UIResponder? = window
            while responder?.next != nil {
                responder = responder?.next
            }
        }
        return nil
    }
}
