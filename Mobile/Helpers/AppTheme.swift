import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "Как на устройстве"
        case .light:
            return "Светлая"
        case .dark:
            return "Тёмная"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AppColors {
    static let darkBackground = Color(red: 0.05, green: 0.08, blue: 0.13)
    static let darkSurface = Color(red: 0.08, green: 0.12, blue: 0.19)
    static let lightBackground = Color(red: 0.97, green: 0.98, blue: 1.0)
    static let lightSurface = Color.white
}
