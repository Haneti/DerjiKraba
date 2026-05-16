//
//  InventoryReportView.swift
//  DerjiKraba
//
//  Created for displaying inventory report
//

import SwiftUI
import SwiftData

// MARK: - SnapshotItem (независимая копия данных)

struct SnapshotItem {
    let productName: String
    let systemQuantity: Double
    let actualQuantity: Double
    let pricePerKg: Double
    
    var difference: Double {
        actualQuantity - systemQuantity
    }
}

struct InventoryReportView: View {
    // Полная копия данных для защиты от изменений
    private let snapshotItems: [SnapshotItem]
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    // Кэшируем значения СРАЗУ при создании View
    private let shortagesCount: Int
    private let surplusesCount: Int
    private let normalCount: Int
    private let totalCount: Int
    
    init(items: [InventoryView.InventoryItem]) {
        // Создаем независимую копию данных
        self.snapshotItems = items.map { item in
            SnapshotItem(
                productName: item.product.name,
                systemQuantity: item.systemQuantity,
                actualQuantity: item.actualQuantity,
                pricePerKg: item.product.pricePerKg
            )
        }
        
        // Вычисляем все значения один раз при инициализации
        self.totalCount = snapshotItems.count
        self.shortagesCount = snapshotItems.filter { $0.difference < -0.01 }.count
        self.surplusesCount = snapshotItems.filter { $0.difference > 0.01 }.count
        self.normalCount = snapshotItems.filter { abs($0.difference) <= 0.01 }.count
    }
    
    private var shortages: [SnapshotItem] {
        snapshotItems.filter { $0.difference < -0.01 }
    }
    
    private var surpluses: [SnapshotItem] {
        snapshotItems.filter { $0.difference > 0.01 }
    }
    
    private var normal: [SnapshotItem] {
        snapshotItems.filter { abs($0.difference) <= 0.01 }
    }
    
    private var totalShortageValue: Double {
        shortages.reduce(0) { $0 + ($1.difference * $1.pricePerKg) }
    }
    
    private var totalSurplusValue: Double {
        surpluses.reduce(0) { $0 + ($1.difference * $1.pricePerKg) }
    }
    
    private var hasOnlySurpluses: Bool {
        surplusesCount > 0 && shortagesCount == 0
    }
    
    private var hasShortages: Bool {
        shortagesCount > 0
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if snapshotItems.isEmpty {
                    // Защита от пустого массива
                    emptyReportView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Общая статистика
                            summaryCards
                            
                            // Недостачи
                            if !shortages.isEmpty {
                                problemSection(
                                    title: "Недостачи",
                                    icon: "arrow.down.circle.fill",
                                    color: .red,
                                    items: shortages
                                )
                            }
                            
                            // Излишки
                            if !surpluses.isEmpty {
                                problemSection(
                                    title: "Излишки",
                                    icon: "arrow.up.circle.fill",
                                    color: .green,
                                    items: surpluses
                                )
                            }
                            
                            // Отображение в зависимости от ситуации
                            if shortages.isEmpty && surpluses.isEmpty {
                                successView
                            } else if hasOnlySurpluses {
                                surplusOnlyView
                            } else if hasShortages {
                                shortageWarningView
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Отчет")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Empty Report View (защита от краша)
    
    private var emptyReportView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Нет данных для отображения")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Отчет не может быть сформирован")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Summary Cards
    
    private var summaryCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Всего товаров
                SummaryCard(
                    title: "Всего товаров",
                    value: "\(totalCount)",
                    icon: "square.grid.2x2",
                    color: .blue
                )
                
                // В норме
                SummaryCard(
                    title: "В норме",
                    value: "\(normalCount)",
                    icon: "checkmark.circle",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                // Недостачи
                SummaryCard(
                    title: "Недостачи",
                    value: "\(shortagesCount)",
                    icon: "arrow.down.circle",
                    color: .red
                )
                
                // Излишки
                SummaryCard(
                    title: "Излишки",
                    value: "\(surplusesCount)",
                    icon: "arrow.up.circle",
                    color: .green
                )
            }
            
            // Финансовый итог
            if !shortages.isEmpty || !surpluses.isEmpty {
                VStack(spacing: 8) {
                    if !shortages.isEmpty {
                        HStack {
                            Text("Сумма недостач:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("-\(abs(Int(totalShortageValue))) ₽")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if !surpluses.isEmpty {
                        HStack {
                            Text("Сумма излишков:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("+\(Int(totalSurplusValue)) ₽")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Problem Section
    
    private func problemSection(
        title: String,
        icon: String,
        color: Color,
        items: [SnapshotItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            
            if !items.isEmpty {
                ForEach(items.indices, id: \.self) { index in
                    ProblemItemRow(snapshot: items[index])
                        .id(UUID()) // Force new render on each display
                }
            } else {
                Text("Нет данных")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Всё в порядке!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Расхождений не обнаружено. Все товары соответствуют учетным данным.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Surplus Only View (Yellow checkmark)
    
    private var surplusOnlyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Что-то не так!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Инвентаризация закрыта с расхождением.\nОбнаружен излишек товара (\(surpluses.count) поз.).")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Shortage Warning View (Red X)
    
    private var shortageWarningView: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Что-то не так!")
                .font(.title2)
                .fontWeight(.bold)
            
            if !shortages.isEmpty && !surpluses.isEmpty {
                Text("Инвентаризация закрыта с расхождением.\nНедостача: \(shortages.count) поз., Излишек: \(surpluses.count) поз.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else if !shortages.isEmpty {
                Text("Инвентаризация закрыта с расхождением.\nОбнаружена недостача товара (\(shortages.count) поз.).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - SummaryCard

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - ProblemItemRow

struct ProblemItemRow: View {
    let snapshot: SnapshotItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.productName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Система: \(String(format: "%.2f", snapshot.systemQuantity)) кг")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Факт: \(String(format: "%.2f", snapshot.actualQuantity)) кг")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(snapshot.difference < 0 ? .red : .green)
                    
                    let diffText = snapshot.difference < 0 
                        ? String(format: "%.2f", snapshot.difference)
                        : String(format: "+%.2f", snapshot.difference)
                    
                    Text(diffText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(snapshot.difference < 0 ? .red : .green)
                }
            }
            
            if abs(snapshot.difference) > 0.01 {
                let value = abs(snapshot.difference) * snapshot.pricePerKg
                Text("Сумма: \(String(format: "%.2f", value)) ₽")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    InventoryReportView(items: [])
        .environment(AppState())
}
