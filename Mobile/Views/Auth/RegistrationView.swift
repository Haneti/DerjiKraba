//
//  RegistrationView.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import SwiftUI

struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phoneInput = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var currentStep: RegistrationStep = .enterData
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    private let telegramBotUsername = "DerjiKraba_Bot" // Replace with your bot username
    
    enum RegistrationStep {
        case enterData
        case linkTelegram
        case enterCode
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    switch currentStep {
                    case .enterData:
                        enterDataView
                    case .linkTelegram:
                        linkTelegramView
                    case .enterCode:
                        // This case is handled by sheet
                        EmptyView()
                    }
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
            .sheet(isPresented: Binding(
                get: { currentStep == .enterCode },
                set: { if !$0 { currentStep = .linkTelegram } }
            )) {
                SMSVerificationView(
                    phone: PhoneFormatter.normalize(phoneInput),
                    firstName: firstName,
                    lastName: lastName,
                    isRegistration: true
                )
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Step 1: Enter Data View
    private var enterDataView: some View {
        VStack(spacing: 24) {
            // Logo
            VStack(spacing: 16) {
                Text("🦀")
                    .font(.system(size: 80))
                
                Text("Регистрация")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Создайте аккаунт для оформления заказов")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Registration form
            VStack(spacing: 20) {
                // Last name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Фамилия")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Иванов", text: $lastName)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.familyName)
                        .autocapitalization(.words)
                }
                
                // First name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Имя")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Иван", text: $firstName)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.givenName)
                        .autocapitalization(.words)
                }
                
                // Phone number
                VStack(alignment: .leading, spacing: 8) {
                    Text("Номер телефона")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("+7")
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.leading, 12)
                        
                        TextField("9998885522", text: $phoneInput)
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
                        Text("Номер будет: \(PhoneFormatter.format(phoneInput))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            
            // Continue button
            Button(action: registerAndProceed) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Продолжить")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(isFormValid && !isLoading ? Color.blue : Color.gray)
            .cornerRadius(12)
            .disabled(!isFormValid || isLoading)
            .padding(.horizontal)
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Link Telegram View
    private var linkTelegramView: some View {
        VStack(spacing: 24) {
            // Telegram icon
            VStack(spacing: 16) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Привяжите Telegram")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Для подтверждения регистрации привяжите ваш Telegram")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                instructionRow(number: "1", text: "Откройте Telegram")
                instructionRow(number: "2", text: "Найдите бота @\(telegramBotUsername)")
                instructionRow(number: "3", text: "Отправьте команду:")
                
                // Command to copy
                let command = "/start \(PhoneFormatter.normalize(phoneInput))"
                HStack {
                    Text(command)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button(action: {
                        UIPasteboard.general.string = command
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Open Telegram button
            Button(action: openTelegram) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Открыть Telegram")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 0.0, green: 0.53, blue: 0.8)) // Telegram blue
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
                Text("После привязки")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Get code button
            Button(action: requestCode) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Получить код")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(isLoading ? Color.gray : Color.blue)
            .cornerRadius(12)
            .disabled(isLoading)
            .padding(.horizontal)
            
            // Back button
            Button(action: { currentStep = .enterData }) {
                Text("Назад")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        phoneInput.count == 10
    }
    
    private func registerAndProceed() {
        isLoading = true
        Task {
            do {
                let api = APIClient()
                // Register user on server (creates user without telegram linked)
                _ = try await api.registerUser(
                    phone: PhoneFormatter.normalize(phoneInput),
                    firstName: firstName,
                    lastName: lastName,
                    middleName: nil
                )
                await MainActor.run {
                    isLoading = false
                    currentStep = .linkTelegram
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func openTelegram() {
        // Try to open bot directly with deep link
        if let url = URL(string: "tg://resolve?domain=\(telegramBotUsername)&start=\(PhoneFormatter.normalize(phoneInput))") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        // Fallback to web link
        if let url = URL(string: "https://t.me/\(telegramBotUsername)?start=\(PhoneFormatter.normalize(phoneInput))") {
            UIApplication.shared.open(url)
        }
    }
    
    private func requestCode() {
        isLoading = true
        Task {
            do {
                let api = APIClient()
                try await api.requestCode(phone: PhoneFormatter.normalize(phoneInput))
                await MainActor.run {
                    isLoading = false
                    currentStep = .enterCode
                }
            } catch let error as NSError {
                await MainActor.run {
                    isLoading = false
                    if error.localizedDescription.contains("не привязан") {
                        errorMessage = "Telegram ещё не привязан. Отправьте команду боту и попробуйте снова."
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showingError = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// Custom text field style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
    }
}

#Preview {
    RegistrationView()
}
