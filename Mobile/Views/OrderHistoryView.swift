//
//  OrderHistoryView.swift
//  DerjiKraba
//
//  Created by Agent on 19.11.2025.
//

import SwiftUI
import SwiftData

struct OrderHistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var orders: [OrderDTO] = []
    @State private var isLoading = false

    private var myCompleted: [OrderDTO] {
        orders.filter { $0.status == "completed" }
    }
    
    private func itemsSummary(for order: OrderDTO) -> String? {
        guard let items = order.items, !items.isEmpty else { return nil }
        let names = items.compactMap { $0.productName }.filter { !$0.isEmpty }
        if names.count >= 2 {
            if names.count == 2 {
                return "\(names[0]), \(names[1])"
            } else {
                return "\(names[0]), \(names[1]) и ещё \(names.count - 2)"
            }
        } else if let first = names.first {
            return first
        } else {
            return "\(items.count) товаров"
        }
    }

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if myCompleted.isEmpty {
                Section {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Нет заказов")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(myCompleted, id: \.id) { order in
                    NavigationLink(destination: OrderHistoryDetailView(order: order)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Заказ #\(order.id.prefix(8))")
                                    .font(.headline)
                                Spacer()
                                Text(humanStatus(order.status))
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            Text(format(date: order.orderDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let summary = itemsSummary(for: order) {
                                Text(summary)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            HStack {
                                Image(systemName: "creditcard.fill").foregroundColor(.blue)
                                Text("\(Int(order.totalAmount)) ₽")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("История заказов")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @MainActor
    private func load() async {
        guard let user = appState.currentUser, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let api = APIClient(baseURL: URL(string: "https://derji-kraba.ru/api")!)
            orders = try await api.fetchOrders(forUser: user.id.uuidString)
        } catch {
            print("❌ Ошибка загрузки истории: \(error)")
        }
    }

    private func format(date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date)
    }
    
    private func humanStatus(_ status: String) -> String {
        switch status {
        case "pending": return "Ожидает обработки"
        case "processing": return "В обработке"
        case "ready": return "Готов к выдаче"
        case "delivering": return "Доставляется"
        case "completed": return "Выполнен"
        case "cancelled": return "Отменен"
        default: return status
        }
    }
}

struct OrderHistoryDetailView: View {
    let order: OrderDTO
    
    private var humanStatus: String {
        switch order.status {
        case "pending": return "Ожидает обработки"
        case "processing": return "В обработке"
        case "ready": return "Готов к выдаче"
        case "delivering": return "Доставляется"
        case "completed": return "Выполнен"
        case "cancelled": return "Отменен"
        default: return order.status
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Общая информация
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Заказ #\(order.id.prefix(8))")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Text(humanStatus)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                    Text(format(date: order.orderDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Состав заказа
                VStack(alignment: .leading, spacing: 12) {
                    Text("Состав заказа")
                        .font(.headline)
                    
                    if let items = order.items, !items.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(items, id: \.id) { item in
                                OrderHistoryItemRow(item: item)
                            }
                        }
                    } else {
                        Text("Нет данных о товарах в этом заказе")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Итого
                HStack {
                    Text("Итого:")
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(Int(order.totalAmount)) ₽")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Детали заказа")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func format(date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date)
    }
}

/// Строка товара в деталях истории заказа (для клиента)
struct OrderHistoryItemRow: View {
    let item: OrderItemDTO
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Полное название товара
                Text(item.productName ?? "Товар")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
                
                // Вес и цена за кг
                Text(String(format: "%.2f кг × %d ₽/кг", item.quantity, Int(item.pricePerKg)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Стоимость позиции
            Text("\(Int(item.quantity * item.pricePerKg)) ₽")
                .font(.subheadline)
                .fontWeight(.bold)
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
