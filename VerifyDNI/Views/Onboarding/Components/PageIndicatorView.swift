// PageIndicatorView.swift
// VerifyDNI
// Indicador de página animado con cápsulas — se expande la activa.

import SwiftUI

struct PageIndicatorView: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current
                          ? Color(hex: "#1877FF")
                          : Color.white.opacity(0.18))
                    .frame(width: i == current ? 24 : 7, height: 7)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: current)
            }
        }
    }
}
