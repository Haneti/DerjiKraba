//
//  LoginView.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var phoneInput = ""
    @State private var showingSMSVerification = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Логотип
                    VStack(spacing: 16) {
                        Text("🦀")
                            .font(.system(size: 80))
                        
                        Text("Вход")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Введите номер телефона для входа")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    
                    // Номер телефона
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Номер телефона")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("+7")
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.leading, 12)
                            
                            TextField("9841752998", text: $phoneInput)
                                .keyboardType(.numberPad)
                                .onChange(of: phoneInput) { oldValue, newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered.count > 10 {
                                        phoneInput = String(filtered.prefix(10))
                                    } else {
                                        phoneInput = filtered
                                    }
                                }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        if !phoneInput.isEmpty {
                            Text("Номер: \(PhoneFormatter.format(phoneInput))")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Кнопка входа
                    Button(action: login) {
                        Text("Получить код")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(phoneInput.count == 10 ? Color.blue : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(phoneInput.count != 10)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSMSVerification) {
                SMSVerificationView(
                    phone: PhoneFormatter.normalize(phoneInput),
                    firstName: "",
                    lastName: "",
                    isRegistration: false
                )
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func login() {
        // Больше не проверяем локальную SwiftData-базу.
        // Истинный источник данных — сервер: наличие пользователя
        // проверяется в SMSVerificationView через API /auth/login.
        showingSMSVerification = true
    }
}

#Preview {
    LoginView()
        .modelContainer(for: [User.self])
}
