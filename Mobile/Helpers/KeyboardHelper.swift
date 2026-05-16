//
//  KeyboardHelper.swift
//  DerjiKraba
//
//  Helper for hiding keyboard
//

import SwiftUI

extension View {
    /// Скрывает клавиатуру на iOS
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
