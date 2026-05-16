//
//  InventoryView.swift
//  DerjiKraba
//
//  Created for inventory management
//

import SwiftUI
import SwiftData

struct InventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Product.name) private var products: [Product]
    
    @State private var inventoryItems: [InventoryItem] = []
    @State private var showingReport = false
    @State private var isProcessing = false
    @State private var selectedFilter: InventoryFilter = .all
    @State private var showingConfirmation = false
    @State private var filterCounts: FilterCounts = FilterCounts(all: 0, shortages: 0, surpluses: 0, normal: 0)
    
    enum InventoryFilter: String, CaseIterable {
        case all = "Все"
        case shortages = "Недостачи"
        case surpluses = "Излишки"
        case normal = "В норме"
    }
    
    struct FilterCounts {
        var all: Int = 0
        var shortages: Int = 0
        var surpluses: Int = 0
        var normal: Int = 0
    }
    
    struct InventoryItem: Identifiable {
        let id = UUID()
        let product: Product
        let systemQuantity: Double
        var actualQuantity: Double
        var isEditing: Bool = false
        
        var difference: Double {
            actualQuantity - systemQuantity
        }
        
        var adjustmentType: AdjustmentType {
            if difference < -0.01 { return .shortage }
            if difference > 0.01 { return .surplus }
            return .adjustment
        }
    }
    
    var filteredItems: [InventoryItem] {
        switch selectedFilter {
        case .all:
            return inventoryItems
        case .shortages:
            return inventoryItems.filter { $0.difference < -0.01 }
        case .surpluses:
            return inventoryItems.filter { $0.difference > 0.01 }
        case .normal:
            return inventoryItems.filter { abs($0.difference) <= 0.01 }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Фильтры
                if !inventoryItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterChip(
                                title: InventoryFilter.all.rawValue,
                                count: filterCounts.all,
                                isSelected: selectedFilter == .all
                            ) {
                                selectedFilter = .all
                            }
                            
                            FilterChip(
                                title: InventoryFilter.shortages.rawValue,
                                count: filterCounts.shortages,
                                isSelected: selectedFilter == .shortages
                            ) {
                                selectedFilter = .shortages
                            }
                            
                            FilterChip(
                                title: InventoryFilter.surpluses.rawValue,
                                count: filterCounts.surpluses,
                                isSelected: selectedFilter == .surpluses
                            ) {
                                selectedFilter = .surpluses
                            }
                            
                            FilterChip(
                                title: InventoryFilter.normal.rawValue,
                                count: filterCounts.normal,
                                isSelected: selectedFilter == .normal
                            ) {
                                selectedFilter = .normal
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                }
                
                // Список товаров
                if inventoryItems.isEmpty {
                    startInventoryView
                } else if filteredItems.isEmpty {
                    emptyFilterView
                } else {
                    inventoryListView
                }
                
                // Кнопка завершения
                if !inventoryItems.isEmpty {
                    finishButton
                }
            }
            .navigationTitle("Инвентаризация")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !inventoryItems.isEmpty {
                        Button("Отмена") {
                            withAnimation {
                                inventoryItems.removeAll()
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingReport) {
                InventoryReportView(items: inventoryItems)
            }
            .alert("Завершить инвентаризацию?", isPresented: $showingConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Закрыть с расхождениями", role: .destructive) {
                    Task {
                        await applyInventoryChanges()
                    }
                }
            } message: {
                Text("Будут внесены следующие изменения:\n• Недостачи: \(shortagesCount)\n• Излишки: \(surplusesCount)\n\nПосле подтверждения количество товаров в системе будет обновлено.")
            }
        }
        .task {
            await loadProductsForInventory()
        }
    }
    
    // MARK: - Views
    
    private var startInventoryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Начать инвентаризацию")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Пересчитайте все товары на складе и внесите фактические значения")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: startInventory) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Начать пересчет")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: 200)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var emptyFilterView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Нет товаров в этой категории")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    private var inventoryListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach($inventoryItems) { $item in
                    if shouldShow(item) {
                        InventoryItemRow(item: $item)
                            .onChange(of: item.actualQuantity) { _, _ in
                                // Обновляем счетчики фильтров при изменении значения
                                updateFilterCounts()
                            }
                    }
                }
            }
            .padding()
        }
    }
    
    private var finishButton: some View {
        VStack {
            Divider()
            
            Button(action: {
                if hasDifferences {
                    showingConfirmation = true
                } else {
                    Task {
                        await applyInventoryChanges()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Завершить инвентаризацию")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(hasDifferences ? Color.orange : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isProcessing)
            .padding()
            
            if hasDifferences {
                Text("⚠️ Обнаружены расхождения (\(shortagesCount) недостач, \(surplusesCount) излишков)")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Logic
    
    private func shouldShow(_ item: InventoryItem) -> Bool {
        switch selectedFilter {
        case .all: return true
        case .shortages: return item.difference < -0.01
        case .surpluses: return item.difference > 0.01
        case .normal: return abs(item.difference) <= 0.01
        }
    }
    
    @MainActor
    private func loadProductsForInventory() async {
        guard inventoryItems.isEmpty else { return }
        
        let availableProducts = products.filter { $0.isAvailable }
        
        withAnimation {
            inventoryItems = availableProducts.map { product in
                InventoryItem(
                    product: product,
                    systemQuantity: product.quantityInStock,
                    actualQuantity: product.quantityInStock
                )
            }
            updateFilterCounts()
        }
    }
    
    private func updateFilterCounts() {
        filterCounts.all = inventoryItems.count
        filterCounts.shortages = inventoryItems.filter { $0.difference < -0.01 }.count
        filterCounts.surpluses = inventoryItems.filter { $0.difference > 0.01 }.count
        filterCounts.normal = inventoryItems.filter { abs($0.difference) <= 0.01 }.count
    }
    
    private func startInventory() {
        Task {
            await loadProductsForInventory()
        }
    }
    
    private var hasDifferences: Bool {
        inventoryItems.contains { abs($0.difference) > 0.01 }
    }
    
    private var shortagesCount: Int {
        inventoryItems.filter { $0.difference < -0.01 }.count
    }
    
    private var surplusesCount: Int {
        inventoryItems.filter { $0.difference > 0.01 }.count
    }
    
    private func applyInventoryChanges() async {
        guard let currentUser = appState.currentUser else { return }
        
        await MainActor.run {
            isProcessing = true
        }
        
        print("🔄 Начало синхронизации с сервером...")
        
        var failedUpdates: [String] = []
        
        // Принудительно сохраняем все значения из TextField перед отправкой
        for item in inventoryItems {
            // Убеждаемся, что значение актуально
            print("📝 Товар '\(item.product.name)': факт=\(item.actualQuantity), разница=\(item.difference)")
        }
        
        // Создаем записи о корректировках и обновляем товары НА СЕРВЕРЕ
        for item in inventoryItems where abs(item.difference) > 0.01 {
            do {
                // 1. Обновляем ТОЛЬКО количество товара на сервере
                let api = APIClient(baseURL: URL(string: "http://87.225.104.51:3000")!)
                
                // Отправляем только quantity_in_stock
                var updateBody: [String: Any] = [:]
                updateBody["quantity_in_stock"] = item.actualQuantity
                
                print("📤 Отправка PATCH запроса для '\(item.product.name)': quantity=\(item.actualQuantity)")
                
                let updatedProduct = try await api.updateProductMinimal(
                    id: item.product.id.uuidString,
                    body: updateBody
                )
                
                print("✅ Товар '\(item.product.name)' обновлен на сервере: \(item.systemQuantity) → \(updatedProduct.quantityInStock)")
                
                // 2. Создаем локальную запись об инвентаризации
                let adjustment = InventoryAdjustment(
                    productId: item.product.id,
                    productName: item.product.name,
                    systemQuantity: item.systemQuantity,
                    actualQuantity: item.actualQuantity,
                    adjustmentType: item.adjustmentType,
                    reason: nil,
                    performedBy: currentUser.id
                )
                
                modelContext.insert(adjustment)
                
                // 3. Обновляем локальную SwiftData модель данными с сервера
                item.product.quantityInStock = updatedProduct.quantityInStock
                
            } catch {
                print("❌ Ошибка обновления товара '\(item.product.name)': \(error)")
                failedUpdates.append(item.product.name)
                // Продолжаем работу даже если один товар не обновился
            }
        }
        
        // Сохраняем локальные данные (инвентаризацию)
        do {
            try modelContext.save()
            print("✅ Локальные данные сохранены в SwiftData")
            
            if !failedUpdates.isEmpty {
                print("⚠️ Не удалось обновить товары: \(failedUpdates.joined(separator: ", "))")
            }
            
            // Показываем отчет СРАЗУ с текущими данными
            await MainActor.run {
                showingReport = true
                print("✅ Отчет показан")
                
                // НЕ очищаем список - отчет использует snapshot данных
                /* Пользователь может закрыть отчет когда угодно
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        inventoryItems.removeAll()
                        isProcessing = false
                    }
                    print("✅ Список очищен после закрытия отчета")
                }
                 */
            }
        } catch {
            print("❌ Ошибка сохранения: \(error)")
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

// MARK: - InventoryItemRow

struct InventoryItemRow: View {
    @Binding var item: InventoryView.InventoryItem
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Изображение товара
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                    
                    if let imageURL = item.product.imageURL, !imageURL.isEmpty {
                        CachedAsyncImageView(
                            imageURL: imageURL,
                            placeholderName: nil,
                            imageHash: item.product.imageHash
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ImagePlaceholderView(productName: item.product.name)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(width: 50, height: 50)
                
                // Информация о товаре
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.product.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Text("\(String(format: "%.2f", item.systemQuantity)) \(item.product.unitShortLabel) в системе")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Ввод фактического количества
                VStack(alignment: .trailing, spacing: 4) {
                    TextField("Факт", value: $item.actualQuantity, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($isTextFieldFocused)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onChange(of: item.actualQuantity) { _, newValue in
                            item.isEditing = true
                        }
                        .submitLabel(.done)
                    
                    differenceBadge(item)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3)
    }
    
    @ViewBuilder
    private func differenceBadge(_ item: InventoryView.InventoryItem) -> some View {
        let diff = item.difference
        
        if abs(diff) <= 0.01 {
            Label("Норма", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
        } else if diff < 0 {
            Label(String(format: "%.2f", diff), systemImage: "arrow.down.circle.fill")
                .font(.caption2)
                .foregroundColor(.red)
        } else {
            Label(String(format: "+%.2f", diff), systemImage: "arrow.up.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
        }
    }
}

// MARK: - FilterChip

struct FilterChip: View {
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

#Preview {
    InventoryView()
        .environment(AppState())
        .modelContainer(for: [Product.self, InventoryAdjustment.self])
}
