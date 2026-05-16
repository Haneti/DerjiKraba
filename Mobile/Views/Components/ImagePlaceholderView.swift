//
//  ImagePlaceholderView.swift
//  DerjiKraba
//
//  Компонент для отображения изображения-заглушки из Assets или системной иконки
//

import SwiftUI

struct ImagePlaceholderView: View {
    let productName: String
    
    var body: some View {
        Group {
            // Пытаемся найти изображение в Assets по имени товара
            if let image = UIImage(named: productName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Если изображения нет - показываем красивую заглушку с первой буквой
                ZStack {
                    Color.blue.opacity(0.2)
                    
                    VStack(spacing: 4) {
                        // Первая буква названия
                        Text(String(productName.prefix(1)).uppercased())
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.blue)
                        
                        // Иконка морепродуктов
                        Image(systemName: getIconForProduct(productName))
                            .font(.system(size: 20))
                            .foregroundColor(.blue.opacity(0.6))
                    }
                }
            }
        }
    }
    
    // Подбор иконки по названию товара
    private func getIconForProduct(_ name: String) -> String {
        let lowercased = name.lowercased()
        
        switch lowercased {
        case "краб", "crab":
            return "star.fill"
        case "креветк", "shrimp":
            return "bolt.fill"
        case "рыб", "fish", "лосось", "семг", "горбуш":
            return "fish.fill"
        case "икр", "caviar":
            return "circle.fill"
        case "кальмар", "squid":
            return "wind"
        case "миди", "mussel":
            return "oval.fill"
        case "осьминог", "octopus":
            return "globe"
        case "гребешок", "scallop":
            return "seashell.fill"
        case "рак", "lobster":
            return "ant.fill"
        case "тунец", "tuna":
            return "flame.fill"
        case "угорь", "eel":
            return "waveform.path.ecg"
        default:
            return "shippingbox.fill"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Пример с существующим изображением
        ImagePlaceholderView(productName: "Камчатский краб")
            .frame(width: 100, height: 100)
        
        // Пример без изображения (покажет заглушку)
        ImagePlaceholderView(productName: "Неизвестный продукт")
            .frame(width: 100, height: 100)
    }
    .padding()
}
