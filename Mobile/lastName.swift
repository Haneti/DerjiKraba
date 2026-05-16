//
//  DerjiKrabaApp.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import SwiftUI
import SwiftData

@main
struct DerjiKrabaApp: App {
    @State private var appState = AppState()
    @AppStorage("appThemeMode") private var appThemeMode = AppThemeMode.system.rawValue
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Product.self,
            User.self,
            Supply.self,
            Order.self,
            OrderItem.self,
            Cart.self,
            CartItem.self
        ])

        do {
            let persistent = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [persistent])
        } catch {
            print("⚠️ Не удалось создать persistent ModelContainer: \(error). Переходим на in-memory хранилище.")
            do {
                let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [inMemory])
            } catch {
                fatalError("Не удалось создать даже in-memory ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(appState)
                .preferredColorScheme(AppThemeMode(rawValue: appThemeMode)?.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
