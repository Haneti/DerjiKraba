//
//  AdminOrdersView.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import SwiftUI
import SwiftData

struct AdminOrdersView: View {
    @Environment(AppState.self) private var appState
    @State private var orders: [OrderDTO] = []
    @State private var isLoading = false
    @State private var selectedFilter: OrderFilter = .all
    @State private var newOrderCount = 0
    @State private var autoRefreshTimer: Timer?
    
    enum OrderFilter: String, CaseIterable {
        case all = "Все"
        case pending = "Ожидают"
        case processing = "В работе"
        case completed = "Выполнены"
        
        func matches(_ order: OrderDTO) -> Bool {
            switch self {
            case .all: return true
            case .pending: return order.status == "pending"
            case .processing: return order.status == "processing" || order.status == "ready"
            case .completed: return order.status == "completed"
            }
        }
    }
    
    var filteredOrders: [OrderDTO] {
        orders.filter { selectedFilter.matches($0) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 0) {

                    // Фильтры
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(OrderFilter.allCases, id: \.self) { filter in
                                FilterButton(
                                    title: filter.rawValue,
                                    count: orders.filter { filter.matches($0) }.count,
                                    isSelected: selectedFilter == filter
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)

                    // Список
                    if isLoading {
                        ProgressView().padding(.top, 20)
                    } else if filteredOrders.isEmpty {
                        EmptyOrdersView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredOrders, id: \.id) { order in
                                    NavigationLink(destination: RemoteOrderDetailView(order: order)) {
                                        AdminOrderCardRemote(order: order)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Заказы")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await loadOrders()
            startAutoRefresh()
        }
        .onDisappear {
            autoRefreshTimer?.invalidate()
        }
    }

    @MainActor
    func loadOrders() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let api = APIClient(baseURL: URL(string: "http://87.225.104.51:3000")!)
            let newOrders = try await api.fetchOrders()
            
            // Проверяем появилисьсь ли новые заказы
            if newOrders.count > orders.count {
                newOrderCount = newOrders.count - orders.count
            }
            
            self.orders = newOrders
        } catch {
            print("❌ Не удалось загрузить заказы: \(error)")
        }
    }
    
    private func startAutoRefresh() {
        // Авто-обновление каждые 10 секунд для заказов
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                await loadOrders()
            }
        }
    }
}

// Кнопка фильтра
struct FilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                    .cornerRadius(8)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(20)
        }
    }
}

// Карточка заказа для админа (remote)
struct AdminOrderCardRemote: View {
    let order: OrderDTO
    @Environment(\.modelContext) private var modelContext
    
    private var itemsSummary: String {
        guard let items = order.items, !items.isEmpty else {
            return "0 товаров"
        }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Заказ #\(order.id.prefix(8))")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(formatDate(order.orderDate))
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                OrderStatusBadgeRemote(status: order.status)
            }
            
            Divider()
            
            // Информация о клиенте
            if let customer = order.customer {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(customer.fullName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(PhoneFormatter.format(customer.phone))
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            } else if let phone = resolvedPhone() {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                    Text(PhoneFormatter.format(phone))
                        .font(.subheadline)
                }
            } else {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                    Text("Гостевой заказ")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
            
            // Краткое содержимое заказа
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundColor(.blue)
                Text(itemsSummary)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                Text("\(Int(order.totalAmount)) ₽")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3)
        .foregroundColor(.primary)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    /// Пытаемся найти локального пользователя по userId заказа, чтобы показать телефон,
    /// если заказ был оформлен авторизованным клиентом.
    private func resolvedPhone() -> String? {
        guard let userId = order.userId else { return nil }
        let descriptor = FetchDescriptor<User>()
        guard let users = try? modelContext.fetch(descriptor) else { return nil }
        return users.first(where: { $0.id.uuidString == userId })?.phone
    }
}

// Бейдж статуса заказа (remote)
struct OrderStatusBadgeRemote: View {
    let status: String
    
    var body: some View {
        Text(humanStatus)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    var humanStatus: String {
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
    
    var backgroundColor: Color {
        switch status {
        case "pending": return .orange
        case "processing": return .blue
        case "ready": return .purple
        case "delivering": return .cyan
        case "completed": return .green
        case "cancelled": return .red
        default: return .gray
        }
    }
}

// Детали заказа (remote)
struct RemoteOrderDetailView: View {
    let order: OrderDTO
    @State private var status: String = "pending"
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Статус
                VStack(alignment: .leading, spacing: 12) {
                    Text("Статус заказа")
                        .font(.headline)
                    
                    Picker("Статус", selection: $status) {
                        Text("Ожидает обработки").tag("pending")
                        Text("В работе").tag("processing")
                        Text("Собран").tag("ready")
                        Text("Выполнен").tag("completed")
                        Text("Отменен").tag("cancelled")
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .onChange(of: status) { _, newValue in
                        Task { try? await APIClient(baseURL: URL(string: "http://87.225.104.51:3000")!).updateOrderStatus(orderId: order.id, status: newValue) }
                    }
                }
                
                Divider()
                
                // Информация о клиенте
                VStack(alignment: .leading, spacing: 12) {
                    Text("Клиент")
                        .font(.headline)
                    
                    if let customer = order.customer {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(icon: "person.fill", title: "Имя", value: customer.fullName)
                            InfoRow(icon: "phone.fill", title: "Телефон", value: PhoneFormatter.format(customer.phone))
                            InfoRow(icon: "mappin.and.ellipse", title: "Адрес", value: customer.address ?? "-")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    } else if let phone = resolvedPhone() {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(icon: "phone.fill", title: "Телефон", value: PhoneFormatter.format(phone))
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        Text("Гостевой заказ")
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Товары
                VStack(alignment: .leading, spacing: 12) {
                    Text("Состав заказа")
                        .font(.headline)
                    
                    if let items = order.items, !items.isEmpty {
                        ForEach(items, id: \.id) { item in
                            OrderItemRow(item: item)
                        }
                    } else {
                        Text("Нет данных о товарах в этом заказе")
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
        .onAppear { status = order.status }
.navigationTitle("Заказ #\(order.id.prefix(8))")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Ищем локального пользователя по userId заказа, чтобы получить телефон,
    /// если заказ был сделан авторизованным клиентом.
    private func resolvedPhone() -> String? {
        guard let userId = order.userId else { return nil }
        let descriptor = FetchDescriptor<User>()
        guard let users = try? modelContext.fetch(descriptor) else { return nil }
        return users.first(where: { $0.id.uuidString == userId })?.phone
    }
}

// Строка товара в заказе
struct OrderItemRow: View {
    let item: OrderItemDTO
    
    var body: some View {
        HStack {
            Text(item.productName ?? "Товар")
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text("\(String(format: "%.1f", item.quantity)) кг × \(Int(item.pricePerKg)) ₽")
                .font(.caption)
                .foregroundColor(.primary)
            Text("= \(Int(item.quantity * item.pricePerKg)) ₽")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// Пустой список заказов
struct EmptyOrdersView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Заказов нет")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Новые заказы появятся здесь")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AdminOrdersView()
        .modelContainer(for: [Order.self, User.self, OrderItem.self])
}
