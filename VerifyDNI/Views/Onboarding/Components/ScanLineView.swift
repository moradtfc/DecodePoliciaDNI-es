// ScanLineView.swift
// VerifyDNI
// Línea de escaneo animada que recorre el interior del frame MRZ.

import SwiftUI

struct ScanLineView: View {
    @State private var offsetY: CGFloat = 0
    private let height: CGFloat

    init(height: CGFloat = 160) {
        self.height = height
    }

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#1877FF").opacity(0),
                        Color(hex: "#60A5FA").opacity(0.9),
                        Color(hex: "#1877FF").opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .shadow(color: Color(hex: "#60A5FA").opacity(0.7), radius: 6, y: 0)
            .offset(y: offsetY)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.6)
                    .repeatForever(autoreverses: true)
                ) {
                    offsetY = height * 0.5 - 1
                }
            }
    }
}
