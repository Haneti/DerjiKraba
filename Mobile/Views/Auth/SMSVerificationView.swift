//
//  SMSVerificationView.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import SwiftUI
import SwiftData

struct SMSVerificationView: View {
    let phone: String
    let firstName: String
    let lastName: String
    let isRegistration: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var code = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var isResending = false
    @State private var didRequestInitialCode = false

    private func mapRole(_ role: String) -> UserRole {
        switch role {
        case "owner":
            return .owner
        case "employee":
            return .employee
        default:
            return .client
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                // Telegram icon
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 60)
                
                // Text
                VStack(spacing: 12) {
                    Text("Подтверждение")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Введите код из Telegram, отправленный на номер:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text(PhoneFormatter.format(phone))
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                // Code input field
                VStack(spacing: 16) {
                    TextField("", text: $code)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 32, weight: .semibold))
                        .frame(maxWidth: 200)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onChange(of: code) { oldValue, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count > 6 {
                                code = String(filtered.prefix(6))
                            } else {
                                code = filtered
                            }
                        }
                        .submitLabel(.done)
                    
                    Text("Введите 6-значный код")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Info hint
                VStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Код действителен 5 минут")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                    Spacer(minLength: 120)
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
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button(action: verify) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Подтвердить")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(code.count == 6 && !isLoading ? Color.blue : Color.gray)
                    .cornerRadius(12)
                    .disabled(code.count != 6 || isLoading)

                    Button(action: resendCode) {
                        if isResending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        } else {
                            Text("Отправить код повторно")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isResending)
                }
                .padding()
                .background(.bar)
            }
            .task {
                guard !isRegistration, !didRequestInitialCode else { return }
                didRequestInitialCode = true
                resendCode()
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func verify() {
        isLoading = true
        Task {
            do {
                let api = APIClient()
                // Verify code via Telegram
                let u = try await api.verifyCode(phone: phone, code: code)
                
                await MainActor.run {
                    // Create or update local user
                    let local = User(
                        phone: u.phone,
                        id: UUID(uuidString: u.id) ?? UUID(),
                        firstName: u.firstName,
                        lastName: u.lastName,
                        middleName: u.middleName,
                        role: mapRole(u.role),
                        isVerified: true
                    )
                    
                    // Check if user already exists locally
                    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.phone == phone })
                    if let existing = try? modelContext.fetch(descriptor).first {
                        existing.id = UUID(uuidString: u.id) ?? existing.id
                        existing.firstName = u.firstName
                        existing.lastName = u.lastName
                        existing.middleName = u.middleName
                        existing.role = mapRole(u.role)
                        existing.isVerified = true
                        try? modelContext.save()
                        appState.login(user: existing)
                    } else {
                        modelContext.insert(local)
                        try? modelContext.save()
                        appState.login(user: local)
                    }
                    
                    isLoading = false
                    dismiss()
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
    
    private func resendCode() {
        isResending = true
        code = ""
        Task {
            do {
                let api = APIClient()
                try await api.requestCode(phone: phone)
                await MainActor.run {
                    isResending = false
                }
            } catch {
                await MainActor.run {
                    isResending = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}
