//
//  AuthView.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import SwiftUI

struct AuthView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingRegistration = false
    @State private var showingLogin = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Логотип
                VStack(spacing: 16) {
                    Text("🦀")
                        .font(.system(size: 100))
                    
                    Text("Держи Краба")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Ул. Аллея Труда 62")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 80)
                
                Spacer()
                
                // Кнопки
                VStack(spacing: 16) {
                    // Регистрация
                    Button(action: { showingRegistration = true }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Зарегистрироваться")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Вход
                    Button(action: { showingLogin = true }) {
                        HStack {
                            Image(systemName: "person.fill")
                            Text("Войти")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    }
                    
                    // Продолжить без входа
                    Button(action: { dismiss() }) {
                        Text("Продолжить без входа")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(isPresented: $showingRegistration) {
                RegistrationView()
            }
            .sheet(isPresented: $showingLogin) {
                LoginView()
            }
        }
    }
}

#Preview {
    AuthView()
}
