//
//  User.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import Foundation
import SwiftData

enum UserRole: String, Codable {
    case client = "Клиент"
    case employee = "Сотрудник"
    case owner = "Владелец"

    init(apiValue: String) {
        switch apiValue {
        case "owner":
            self = .owner
        case "employee":
            self = .employee
        default:
            self = .client
        }
    }

    var apiValue: String {
        switch self {
        case .client:
            return "client"
        case .employee:
            return "employee"
        case .owner:
            return "owner"
        }
    }
}

@Model
final class User {
    @Attribute(.unique) var phone: String // Основной идентификатор
    var id: UUID
    var firstName: String // Имя
    var lastName: String // Фамилия
    var middleName: String? // Отчество
    var role: UserRole
    var registrationDate: Date
    var address: String? // Адрес для клиентов (для доставки)
    var isVerified: Bool // Подтвержден ли номер телефона
    
    // Связь с заказами (для клиентов)
    @Relationship(deleteRule: .cascade, inverse: \Order.customer)
    var orders: [Order]?
    
    // Связь с поставками (для сотрудников)
    @Relationship(deleteRule: .nullify, inverse: \Supply.employee)
    var supplies: [Supply]?
    
    init(
        phone: String,
        id: UUID = UUID(),
        firstName: String,
        lastName: String,
        middleName: String? = nil,
        role: UserRole = .client,
        registrationDate: Date = Date(),
        address: String? = nil,
        isVerified: Bool = false
    ) {
        self.phone = phone
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.middleName = middleName
        self.role = role
        self.registrationDate = registrationDate
        self.address = address
        self.isVerified = isVerified
    }
    
    var fullName: String {
        if let middleName = middleName {
            return "\(lastName) \(firstName) \(middleName)"
        }
        return "\(lastName) \(firstName)"
    }
    
    var shortName: String {
        "\(firstName) \(lastName)"
    }
    
    var isEmployee: Bool {
        role == .employee || role == .owner
    }
    
    var isClient: Bool {
        role == .client
    }
    
    var isOwner: Bool {
        role == .owner
    }
}
