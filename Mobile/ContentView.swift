//
//  ContentView.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var products: [Product]
    @Query private var users: [User]
    @State private var isDataInitialized = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Заголовок
                VStack {
                    Text("🦀")
                        .font(.system(size: 60))
                    Text("Держи Краба")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Ул. Аллея Труда 62")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Информация о базе данных
                VStack(spacing: 15) {
                    InfoCard(title: "Товаров в базе", value: "\(products.count)", icon: "cart.fill")
                    InfoCard(title: "Пользователей", value: "\(users.count)", icon: "person.fill")
                    
                    if !products.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Пример товара:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(products.first?.name ?? "")
                                .font(.headline)
                            Text("Цена: \(Int(products.first?.pricePerKg ?? 0)) ₽/кг")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Кнопка инициализации данных
                if products.isEmpty {
                    Button(action: initializeSampleData) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Загрузить тестовые данные")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                } else {
                    Text("База данных SwiftData работает!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("Главная")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func initializeSampleData() {
        SampleDataInitializer.initializeSampleData(modelContext: modelContext)
    }
}

// Карточка информации
struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Product.self, User.self, Supply.self, Order.self, OrderItem.self])
}
