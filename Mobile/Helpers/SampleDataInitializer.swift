//
//  SampleDataInitializer.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import Foundation
import SwiftData

class SampleDataInitializer {
    
    /// Инициализация тестовых данных для разработки
    static func initializeSampleData(modelContext: ModelContext) {
        // Проверяем, есть ли уже данные
        let descriptor = FetchDescriptor<Product>()
        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
            print("Данные уже существуют, пропускаем инициализацию")
            return
        }
        
        // Создаем владельца (главного администратора)
        let owner = User(
            phone: "79841752998", // +7 (984) 175-29-98
            firstName: "Артем",
            lastName: "Никитин",
            middleName: "Русланович",
            role: .owner,
            isVerified: true
        )
        
        // Создаем сотрудника
        let employee = User(
            phone: "79991234567",
            firstName: "Иван",
            lastName: "Иванов",
            middleName: "Иванович",
            role: .employee,
            isVerified: true
        )
        
        // Создаем клиента
        let client = User(
            phone: "79997654321",
            firstName: "Петр",
            lastName: "Петров",
            middleName: "Петрович",
            role: .client,
            address: "г. Комсомольск-на-Амуре, ул. Ленина, д. 1",
            isVerified: true
        )
        
        modelContext.insert(owner)
        modelContext.insert(employee)
        modelContext.insert(client)
        
        // Создаем товары
        let currentDate = Date()
        let calendar = Calendar.current
        
        let products = [
            Product(
                name: "Краб камчатский",
                category: "Крабы",
                pricePerKg: 3500.0,
                quantityInStock: 25.5,
                deliveryDate: calendar.date(byAdding: .day, value: -2, to: currentDate)!,
                expiryDate: calendar.date(byAdding: .day, value: 5, to: currentDate)!,
                productDescription: "Свежий камчатский краб, выловленный в водах Тихого океана"
            ),
            Product(
                name: "Креветки тигровые",
                category: "Креветки",
                pricePerKg: 1200.0,
                quantityInStock: 45.0,
                deliveryDate: calendar.date(byAdding: .day, value: -1, to: currentDate)!,
                expiryDate: calendar.date(byAdding: .day, value: 7, to: currentDate)!,
                productDescription: "Крупные тигровые креветки, охлажденные"
            ),
            Product(
                name: "Лосось атлантический",
                category: "Рыба",
                pricePerKg: 850.0,
                quantityInStock: 60.0,
                deliveryDate: calendar.date(byAdding: .day, value: -3, to: currentDate)!,
                expiryDate: calendar.date(byAdding: .day, value: 4, to: currentDate)!,
                productDescription: "Филе атлантического лосося"
            ),
            Product(
                name: "Кальмар",
                category: "Моллюски",
                pricePerKg: 450.0,
                quantityInStock: 35.0,
                deliveryDate: calendar.date(byAdding: .day, value: -1, to: currentDate)!,
                expiryDate: calendar.date(byAdding: .day, value: 6, to: currentDate)!,
                productDescription: "Тушки кальмара, очищенные"
            ),
            Product(
                name: "Мидии",
                category: "Моллюски",
                pricePerKg: 320.0,
                quantityInStock: 50.0,
                deliveryDate: calendar.date(byAdding: .day, value: -2, to: currentDate)!,
                expiryDate: calendar.date(byAdding: .day, value: 5, to: currentDate)!,
                productDescription: "Свежие мидии в раковинах"
            ),
            Product(
                name: "Икра красная горбуши",
                category: "Икра",
                pricePerKg: 4500.0,
                quantityInStock: 15.0,
                deliveryDate: calendar.date(byAdding: .day, value: -5, to: currentDate)!,
                expiryDate: calendar.date(byAdding: .day, value: 25, to: currentDate)!,
                productDescription: "Красная икра горбуши первого сорта"
            )
        ]
        
        for product in products {
            modelContext.insert(product)
        }
        
        // Создаем поставку
        let supply = Supply(
            supplyDate: calendar.date(byAdding: .day, value: -2, to: currentDate)!,
            supplier: "ООО 'Дары океана'",
            totalWeight: 231.5,
            totalCost: 285000.0,
            notes: "Поставка прошла без замечаний, все товары в отличном состоянии",
            employee: employee
        )
        supply.products = Array(products.prefix(4))
        modelContext.insert(supply)
        
        // Создаем тестовый заказ
        let order = Order(
            orderDate: currentDate,
            status: .pending,
            deliveryType: .delivery,
            deliveryAddress: client.address,
            totalAmount: 0,
            customer: client
        )
        
        let orderItem1 = OrderItem(
            product: products[0],
            quantity: 2.0,
            pricePerKg: products[0].pricePerKg
        )
        orderItem1.order = order
        
        let orderItem2 = OrderItem(
            product: products[1],
            quantity: 1.5,
            pricePerKg: products[1].pricePerKg
        )
        orderItem2.order = order
        
        order.totalAmount = orderItem1.totalPrice + orderItem2.totalPrice
        order.items = [orderItem1, orderItem2]
        
        modelContext.insert(order)
        modelContext.insert(orderItem1)
        modelContext.insert(orderItem2)
        
        // Сохраняем все изменения
        do {
            try modelContext.save()
            print("✅ Тестовые данные успешно добавлены!")
        } catch {
            print("❌ Ошибка сохранения данных: \(error)")
        }
    }
}
