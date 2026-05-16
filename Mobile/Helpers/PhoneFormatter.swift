//
//  PhoneFormatter.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import Foundation

struct PhoneFormatter {
    
    /// Форматирует номер телефона в красивый вид: +7 (984) 175-29-98
    static func format(_ phone: String) -> String {
        // Убираем все нецифровые символы
        let digits = phone.filter { $0.isNumber }
        
        // Если номер начинается с 8, заменяем на 7
        var cleanDigits = digits
        if cleanDigits.first == "8" {
            cleanDigits.removeFirst()
            cleanDigits = "7" + cleanDigits
        }
        
        // Если номер не начинается с 7, добавляем 7
        if cleanDigits.first != "7" {
            cleanDigits = "7" + cleanDigits
        }
        
        // Форматируем: +7 (XXX) XXX-XX-XX
        guard cleanDigits.count == 11 else { return "+7 (\(phone))" }
        
        let country = cleanDigits.prefix(1) // 7
        let code = cleanDigits.dropFirst(1).prefix(3) // 984
        let first = cleanDigits.dropFirst(4).prefix(3) // 175
        let second = cleanDigits.dropFirst(7).prefix(2) // 29
        let third = cleanDigits.dropFirst(9).prefix(2) // 98
        
        return "+\(country) (\(code)) \(first)-\(second)-\(third)"
    }
    
    /// Очищает номер телефона от форматирования и оставляет только цифры
    static func clean(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        
        // Если начинается с 8, заменяем на 7
        var cleanDigits = digits
        if cleanDigits.first == "8" {
            cleanDigits.removeFirst()
            cleanDigits = "7" + cleanDigits
        }
        
        // Если не начинается с 7, добавляем 7
        if cleanDigits.first != "7" {
            cleanDigits = "7" + cleanDigits
        }
        
        return cleanDigits
    }
    
    /// Добавляет +7 к номеру, если пользователь ввел только 10 цифр
    static func normalize(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        
        if digits.count == 10 {
            return "7" + digits
        }
        
        return clean(input)
    }
    
    /// Проверяет валидность номера телефона
    static func isValid(_ phone: String) -> Bool {
        let cleaned = clean(phone)
        return cleaned.count == 11 && cleaned.first == "7"
    }
}
