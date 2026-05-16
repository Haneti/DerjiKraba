//
//  BrandTitleView.swift
//  DerjiKraba
//
//  Created by Agent on 19.11.2025.
//

import SwiftUI

struct BrandTitleView: View {
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Text("🦀")
                .font(.system(size: 22))
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}
