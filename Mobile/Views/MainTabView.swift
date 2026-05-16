//
//  MainTabView.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import SwiftUI
import SwiftData
import Combine

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab = 0
    @State private var supportClientHasReply = false
    @State private var supportPendingCount = 0

    private let supportTimer = Timer.publish(every: 12, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Главный контент
            TabView(selection: $selectedTab) {
                // Каталог
                NavigationStack {
                    CatalogView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: { appState.isShowingAuth = true }) {
                                    if let user = appState.currentUser {
                                        HStack(spacing: 6) {
                                            Text(user.firstName)
                                                .font(.subheadline)
                                            Image(systemName: user.isOwner ? "crown.fill" : user.isEmployee ? "person.badge.key.fill" : "person.fill")
                                                .foregroundColor(user.isOwner ? .orange : user.isEmployee ? .blue : .blue)
                                        }
                                    } else {
                                        Image(systemName: "person.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                }
.tabItem {
                    Label("Каталог", systemImage: "square.grid.2x2")
                }
                .tag(0)
                
                // Корзина (теперь доступна для всех пользователей)
                CartView()
                    .tabItem {
                        Label("Корзина", systemImage: "cart.fill")
                    }
                    .badge(appState.cartItemCount > 0 ? appState.cartItemCount : 0)
                    .tag(1)
                
                // Админ панель (для сотрудников и владельца)
                if appState.isEmployee {
                    AdminOrdersView()
                        .tabItem {
                            Label("Заказы", systemImage: "list.clipboard.fill")
                        }
                        .tag(2)
                }

                // Поддержка (для всех; писать может только авторизованный)
                SupportHomeView(selectedTab: $selectedTab)
                    .tabItem {
                        VStack {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "message.fill")

                                // Для клиента: зелёная точка, если последнее сообщение от сотрудника
                                if appState.isClient && supportClientHasReply {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 10, height: 10)
                                        .offset(x: 8, y: -4)
                                }
                            }
                            Text("Поддержка")
                        }
                    }
                    .badge(appState.isEmployee ? supportPendingCount : 0)
                    .tag(3)

                // Управление персоналом (только владелец)
                if appState.currentUser?.role == .owner {
                    NavigationStack {
                        OwnerSettingsView()
                    }
                    .tabItem {
                        Label("Персонал", systemImage: "person.3.fill")
                    }
                    .tag(4)
                }
            }
            
            // Плавающая кнопка корзины (показываем на каталоге если есть товары в корзине)
            if selectedTab == 0 && appState.cartItemCount > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { selectedTab = 1 }) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 60, height: 60)
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                                // Иконка и количество по центру кружка
                                VStack(spacing: 2) {
                                    Image(systemName: "cart.fill")
                                        .font(.headline)
                                    Text("\(appState.cartItemCount)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.isShowingAuth },
            set: { appState.isShowingAuth = $0 }
        )) {
            if appState.isAuthenticated {
                ProfileView()
            } else {
                AuthView()
            }
        }
        .task {
            // Гарантируем наличие владельца и восстанавливаем сессию
            appState.ensureOwnerExists(modelContext: modelContext)
            appState.restoreSession(modelContext: modelContext)
        }
        .task(id: appState.currentUser?.phone ?? "guest") {
            await refreshSupportIndicators()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await refreshSupportIndicators() }
        }
        .onReceive(supportTimer) { _ in
            guard scenePhase == .active else { return }
            Task { await refreshSupportIndicators() }
        }
    }

    @MainActor
    private func refreshSupportIndicators() async {
        guard let user = appState.currentUser else {
            supportClientHasReply = false
            supportPendingCount = 0
            return
        }

        do {
            let api = APIClient(baseURL: URL(string: "http://87.225.104.51:3000")!)

            if user.isEmployee {
                let convs = try await api.fetchSupportConversations()
                supportPendingCount = convs.filter { $0.needsStaffReply }.count
                supportClientHasReply = false
            } else {
                let meta = try await api.fetchSupportConversation(phone: user.phone)
                supportClientHasReply = (meta?.lastSenderRole != nil && meta?.lastSenderRole != "client")
                supportPendingCount = 0
            }
        } catch {
            // Тихо сбрасываем индикаторы (без алертов на главном экране)
            if user.isEmployee {
                supportPendingCount = 0
            } else {
                supportClientHasReply = false
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
        .modelContainer(for: [Product.self, User.self, Order.self, OrderItem.self])
}
