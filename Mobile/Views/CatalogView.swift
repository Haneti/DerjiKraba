//
//  CatalogView.swift
//  DerjiKraba
//
//  Created by Haneti on 19.11.2025.
//

import SwiftUI
import SwiftData

struct CatalogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var products: [ProductDTO] = []
    @State private var searchText = ""
    @State private var selectedCategory = "Все"
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var showingAddProduct = false
    @State private var activeOrder: OrderDTO?
    
    var categories: [String] {
        var cats = ["Все"]
        cats.append(contentsOf: Array(Set(products.map { $0.category })).sorted())
        return cats
    }
    
    var filteredProducts: [ProductDTO] {
        var filtered = products
        let isOwner = appState.currentUser?.isOwner == true
        
        // Для всех, кроме владельца, показываем только доступные товары
        if !isOwner {
            filtered = filtered.filter { $0.isAvailable }
        }
        
        if selectedCategory != "Все" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Для владельца: сперва доступные товары, затем скрытые, внутри по имени
        if isOwner {
            filtered = filtered.sorted { lhs, rhs in
                if lhs.isAvailable == rhs.isAvailable {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.isAvailable && !rhs.isAvailable
            }
        }
        
        return filtered
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Активный заказ клиента (если есть и не выполнен)
                if appState.isClient, let order = activeOrder {
                    ActiveOrderBanner(order: order)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                // Категории
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryButton(
                                title: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                
                // Список товаров
                if isLoading && products.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Загрузка каталога...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else if products.isEmpty {
                    EmptyStateView()
                } else if filteredProducts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Товары не найдены")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredProducts) { product in
                            NavigationLink(destination: ProductDetailView(product: product.toLocalModel(in: modelContext))) {
                                ProductCard(product: product)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 80) // Отступ для корзины
                }
            }
        }
        .searchable(text: $searchText, prompt: "Поиск товаров...")
        .task {
            await loadProducts()
            await loadActiveOrder()
        }
        .refreshable {
            await loadProducts(forceRefresh: true)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                BrandTitleView(title: "Держи Краба")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if appState.currentUser?.isOwner == true {
                    Button {
                        showingAddProduct = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddProduct) {
            AddProductView()
        }
    }
    
    @MainActor
    private func loadProducts(forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // Используем DataCacheManager для кэширования
            let list = try await DataCacheManager.shared.getProducts(forceRefresh: forceRefresh)
            
            // Обновляем локальный стейт
            self.products = list
            
            // Загружаем и кэшируем изображения с проверкой хэшей
            await withTaskGroup(of: Void.self) { group in
                for productDTO in list {
                    if let imageURL = productDTO.imageURL,
                       let imageHash = productDTO.imageHash {
                        group.addTask {
                            do {
                                _ = try await ImageCacheManager.shared.getImage(
                                    for: imageURL,
                                    serverHash: imageHash
                                )
                            } catch {
                                print("❌ Ошибка кэширования изображения: \(error)")
                            }
                        }
                    }
                }
            }
            
            // Синхронизируем с SwiftData для офлайн-доступности
            try syncProductsToSwiftData(list, modelContext: modelContext)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
    
    @MainActor
    private func loadActiveOrder() async {
        guard let user = appState.currentUser, appState.isClient else {
            activeOrder = nil
            return
        }
        do {
            let api = APIClient(baseURL: URL(string: "http://87.225.104.51:3000")!)
            let orders = try await api.fetchOrders(forUser: user.id.uuidString)
            // Берем самый свежий заказ, который ещё не выполнен и не отменен
            let active = orders
                .filter { $0.status != "completed" && $0.status != "cancelled" }
                .sorted(by: { $0.orderDate > $1.orderDate })
            activeOrder = active.first
        } catch {
            // В случае ошибки просто не показываем баннер
            activeOrder = nil
        }
    }
}

// Кнопка категории
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .cornerRadius(20)
        }
    }
}

// Карточка товара
struct ProductCard: View {
    let product: ProductDTO
    
    var body: some View {
        let isHidden = !product.isAvailable
        let primaryTextColor: Color = isHidden ? .gray : .primary
        let secondaryTextColor: Color = isHidden ? .gray : .secondary
        let priceColor: Color = isHidden ? .gray : .blue
        
        return HStack(spacing: 12) {
            // Изображение товара с кэшированием
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                
                if let imageURL = product.imageURL, !imageURL.isEmpty {
                    // Если есть URL - загружаем с сервера через кэш
                    CachedAsyncImageView(
                        imageURL: imageURL,
                        placeholderName: nil,
                        imageHash: product.imageHash
                    )
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Если нет URL - показываем placeholder из Assets по имени товара
                    ImagePlaceholderView(productName: product.name)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(width: 80, height: 80)
            .clipped()
            
            // Информация о товаре
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.headline)
                    .foregroundColor(primaryTextColor)
                
                Text(product.category)
                    .font(.caption)
                    .foregroundColor(primaryTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                    )
                
                HStack {
                    Text("\(Int(product.pricePerKg)) ₽/\(product.unitType == "piece" ? "шт" : "кг")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(priceColor)
                    
                    Spacer()
                    
                    // Индикатор свежести (теперь не показываем для DTO)
                    // if product.daysUntilExpiry <= 2 { ... }
                }
                
                Text("В наличии: \(String(format: "%.1f", product.quantityInStock)) \(product.unitType == "piece" ? "шт" : "кг")")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
            
            Spacer()
            
            // Стрелка
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .opacity(isHidden ? 0.7 : 1.0)
    }
}

// Пустое состояние
struct EmptyStateView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🦀")
                .font(.system(size: 60))
            
            Text("Каталог пуст")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Загрузите тестовые данные для демонстрации")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                SampleDataInitializer.initializeSampleData(modelContext: modelContext)
            }) {
                Text("Загрузить данные")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        CatalogView()
    }
    .environment(AppState())
    .modelContainer(for: [Product.self, User.self, Order.self])
}

// Баннер текущего заказа клиента
struct ActiveOrderBanner: View {
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.white)
                Text("Ваш заказ #\(order.id.prefix(8))")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text("Статус: \(humanStatus)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            
            Text("Сумма: \(Int(order.totalAmount)) ₽")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.blue)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

// Экран добавления нового товара (только владелец)
struct AddProductView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingProducts: [Product]
    
    @State private var name: String = ""
    @State private var category: String = ""
    @State private var priceText: String = ""
    @State private var quantityText: String = ""
    @State private var deliveryDate: Date = Date()
    @State private var expiryDate: Date = Date().addingTimeInterval(86400 * 7)
    @State private var descriptionText: String = ""
    @State private var imageName: String = ""
    @State private var unitType: String = "kg" // "kg" — весовой, "piece" — поштучный
    
    private var categorySuggestions: [String] {
        let all = Set(existingProducts.map { $0.category })
        guard !category.isEmpty else { return Array(all).sorted() }
        return all.filter { $0.localizedCaseInsensitiveContains(category) }.sorted()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Основная информация") {
                    TextField("Название", text: $name)
                    TextField("Категория", text: $category)
                    if !categorySuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categorySuggestions, id: \.self) { suggestion in
                                    Button {
                                        category = suggestion
                                    } label: {
                                        Text(suggestion)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("Тип товара") {
                    Picker("Тип", selection: $unitType) {
                        Text("Весовой").tag("kg")
                        Text("Поштучный").tag("piece")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Параметры") {
                    TextField(unitType == "piece" ? "Цена за 1 шт" : "Цена за кг", text: $priceText)
                        .keyboardType(.decimalPad)
                    TextField(unitType == "piece" ? "Количество на складе (шт)" : "Количество на складе (кг)", text: $quantityText)
                        .keyboardType(.decimalPad)
                    DatePicker("Дата поставки", selection: $deliveryDate, displayedComponents: .date)
                    DatePicker("Срок годности", selection: $expiryDate, displayedComponents: .date)
                }
                
                Section("Описание") {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 80)
                }
                
                Section("Изображение") {
                    TextField("Имя картинки в Assets", text: $imageName)
                        .textInputAutocapitalization(.never)
                }
                
                Section {
                    Button(action: saveProduct) {
                        HStack {
                            Spacer()
                            Text("Сохранить товар")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Новый товар")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty &&
        !category.isEmpty &&
        Double(priceText.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(quantityText.replacingOccurrences(of: ",", with: ".")) != nil
    }
    
    private func saveProduct() {
        let price = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let quantity = Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let product = Product(
            name: name,
            category: category,
            pricePerKg: price,
            quantityInStock: quantity,
            deliveryDate: deliveryDate,
            expiryDate: expiryDate,
            productDescription: descriptionText,
            imageURL: imageName.isEmpty ? nil : imageName,
            isAvailable: true,
            unitType: unitType
        )
        modelContext.insert(product)
        try? modelContext.save()
        dismiss()
    }
}
