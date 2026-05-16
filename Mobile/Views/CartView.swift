//
//  CartView.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import SwiftUI
import SwiftData

struct CartView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var showingCheckout = false
    @State private var deliveryAddress = ""
    @State private var notes = ""
    @State private var wantsCheckout = false
    @State private var orderError: String?
    @State private var showingOrderError = false
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.cartItems.isEmpty {
                    EmptyCartView()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Товары в корзине
                            ForEach(appState.cartItems, id: \.id) { item in
                                CartItemRow(item: item)
                            }
                            
                            // Итоговая информация
                            VStack(spacing: 12) {
                                Divider()
                                
                                HStack {
                                    Text("Итого:")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text(String(format: "%.0f ₽", appState.cartTotal))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                
                                // Кнопка оформления заказа
                                Button(action: {
                                    if appState.isAuthenticated {
                                        showingCheckout = true
                                    } else {
                                        wantsCheckout = true
                                        appState.isShowingAuth = true
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Оформить предзаказ")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandTitleView(title: "Корзина")
                }
            }
            .sheet(isPresented: $showingCheckout) {
                CheckoutView(
                    deliveryAddress: $deliveryAddress,
                    notes: $notes,
                    onCheckout: createOrder
                )
            }
            .onChange(of: appState.isAuthenticated) { oldValue, newValue in
                if newValue, wantsCheckout, !appState.cartItems.isEmpty {
                    showingCheckout = true
                    wantsCheckout = false
                }
            }
            .alert("Ошибка", isPresented: $showingOrderError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(orderError ?? "Не удалось оформить заказ")
            }
        }
    }
    
    private func createOrder() {
        guard let currentUser = appState.currentUser else {
            // Требуется авторизация
            wantsCheckout = true
            appState.isShowingAuth = true
            return
        }
        Task {
            do {
                let items = appState.cartItems.map {
                    OrderItemIn(
                        product_id: $0.product?.id.uuidString ?? "",
                        quantity: $0.quantity,
                        price_per_kg: $0.product?.pricePerKg ?? 0
                    )
                }
                let payload = CreateOrderIn(
                    user_id: currentUser.id.uuidString,
                    delivery_type: "pickup",
                    delivery_address: deliveryAddress.isEmpty ? nil : deliveryAddress,
                    notes: notes.isEmpty ? nil : notes,
                    items: items
                )
                let api = APIClient(baseURL: URL(string: "http://87.225.104.51:3000")!)
                try await api.createOrder(payload)
                // Очищаем корзину локально
                appState.clearCart()
                showingCheckout = false
            } catch {
                orderError = error.localizedDescription
                showingOrderError = true
                print("❌ Ошибка отправки заказа: \(error)")
            }
        }
    }
}

// Строка товара в корзине
struct CartItemRow: View {
    let item: CartItem
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 12) {
            // Изображение товара — используем CachedAsyncImageView как в каталоге
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))

                if let product = item.product, let imageURL = product.imageURL, !imageURL.isEmpty {
                    // Если есть URL - загружаем с сервера через кэш
                    CachedAsyncImageView(
                        imageURL: imageURL,
                        placeholderName: nil,
                        imageHash: product.imageHash
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let product = item.product {
                    // Если нет URL - показываем placeholder из Assets по имени товара
                    ImagePlaceholderView(productName: product.name)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 60, height: 60)
            .clipped()
            
            // Информация о товаре
            VStack(alignment: .leading, spacing: 4) {
                Text(item.product?.name ?? "Товар")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(String(format: "%.2f кг × %d ₽/кг", item.quantity, Int(item.product?.pricePerKg ?? 0)))
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Итог по позиции и кнопка удалить
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f ₽", item.totalPrice))
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Button(action: { appState.removeFromCart(item: item) }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3)
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Крабы": return "crab.fill"
        case "Креветки": return "shrimp.fill"
        case "Рыба": return "fish.fill"
        case "Икра": return "circle.fill"
        default: return "circle.fill"
        }
    }
}

// Пустая корзина
struct EmptyCartView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("Корзина пуста")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Добавьте товары из каталога")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// Оформление заказа
struct CheckoutView: View {
    @Binding var deliveryAddress: String
    @Binding var notes: String
    let onCheckout: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Адрес доставки (опционально)") {
                    TextField("г. Комсомольск-на-Амуре, ул. ...", text: $deliveryAddress)
                }
                
                Section("Примечания") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section {
                    Button(action: {
                        onCheckout()
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text("Оформить заказ")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Оформление заказа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CartView()
        .environment(AppState())
        .modelContainer(for: [Product.self, Order.self, OrderItem.self])
}
