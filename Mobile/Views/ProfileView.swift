//
//  ProfileView.swift
//  DerjiKraba
//
//  Created by Agent on 19.11.2025.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var middleName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingCacheAlert = false
    @State private var cacheSize: Double = 0
    @State private var showingThemeSettings = false
    @AppStorage("appThemeMode") private var appThemeMode = AppThemeMode.system.rawValue

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let user = appState.currentUser {
                    // Шапка
                    HStack(spacing: 12) {
                        Text("🦀").font(.largeTitle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Мой профиль").font(.title2).fontWeight(.bold)
                            Text(user.isOwner ? "Владелец" : (user.isEmployee ? "Сотрудник" : "Клиент"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    Form {
                        Section("Моя информация") {
                            if isEditing {
                                TextField("Фамилия", text: $lastName)
                                TextField("Имя", text: $firstName)
                                TextField("Отчество", text: $middleName)
                            } else {
                                LabeledValueRow(label: "ФИО", value: user.fullName)
                            }
                            LabeledValueRow(label: "Телефон", value: PhoneFormatter.format(user.phone))
                        }

                        Section {
                            Button {
                                showingThemeSettings = true
                            } label: {
                                HStack {
                                    Label("Тема приложения", systemImage: "paintbrush.fill")
                                    Spacer()
                                    Text(AppThemeMode(rawValue: appThemeMode)?.title ?? AppThemeMode.system.title)
                                        .foregroundColor(.secondary)
                                }
                            }

                            NavigationLink(destination: OrderHistoryView()) {
                                Label("История заказов", systemImage: "clock.arrow.circlepath")
                            }
                            
                            // Управление кэшем изображений
                            Button(action: {
                                cacheSize = ImageCacheManager.shared.getCacheSize()
                                showingCacheAlert = true
                            }) {
                                HStack {
                                    Label("Кэш изображений", systemImage: "externaldrive.fill")
                                    Spacer()
                                    Text(String(format: "%.2f МБ", cacheSize))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Section {
                            Button(role: .destructive) {
                                appState.logout()
                                dismiss()
                            } label: {
                                Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Не удалось загрузить профиль")
                            .foregroundColor(.secondary)
                        Button("Закрыть") { dismiss() }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if appState.currentUser != nil {
                        HStack {
                            Button {
                                showingThemeSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }

                            Button(isEditing ? "Сохранить" : "Редактировать") {
                                if isEditing {
                                    save()
                                } else {
                                    loadFields()
                                }
                                isEditing.toggle()
                            }
                        }
                    }
                }
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Кэш изображений", isPresented: $showingCacheAlert) {
                Button("Очистить", role: .destructive) {
                    ImageCacheManager.shared.clearCache()
                    cacheSize = 0
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text(String(format: "Размер кэша: %.2f МБ. Хотите очистить?", cacheSize))
            }
            .sheet(isPresented: $showingThemeSettings) {
                ThemeSettingsView()
            }
            .onAppear { 
                loadFields()
                cacheSize = ImageCacheManager.shared.getCacheSize()
            }
        }
    }

    private func loadFields() {
        guard let user = appState.currentUser else { return }
        firstName = user.firstName
        lastName = user.lastName
        middleName = user.middleName ?? ""
    }

    private func save() {
        guard let user = appState.currentUser else { return }
        user.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.middleName = middleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : middleName
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Не удалось сохранить изменения: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appThemeMode") private var appThemeMode = AppThemeMode.system.rawValue
    @Environment(\.colorScheme) private var systemColorScheme

    private var selectedMode: Binding<AppThemeMode> {
        Binding {
            AppThemeMode(rawValue: appThemeMode) ?? .system
        } set: { newValue in
            appThemeMode = newValue.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Оформление") {
                    Picker("Тема", selection: selectedMode) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Toggle("Автоматически как на устройстве", isOn: Binding(
                        get: { selectedMode.wrappedValue == .system },
                        set: { appThemeMode = ($0 ? AppThemeMode.system : AppThemeMode.dark).rawValue }
                    ))
                }
            }
            .preferredColorScheme((AppThemeMode(rawValue: appThemeMode) ?? .system).colorScheme ?? systemColorScheme)
            .navigationTitle("Тема")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

struct LabeledValueRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}
