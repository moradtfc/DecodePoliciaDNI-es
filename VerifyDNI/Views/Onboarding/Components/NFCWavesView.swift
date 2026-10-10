// NFCWavesView.swift
// VerifyDNI
// Círculos de pulso NFC que se expanden desde el centro — indica lectura del chip.

import SwiftUI

struct NFCWavesView: View {
    @State private var animate = false

    private let waveCount = 3
    private let color = Color(hex: "#1877FF")

    var body: some View {
        ZStack {
            ForEach(0..<waveCount, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(animate ? 0 : 0.55), lineWidth: 1.5)
                    .scaleEffect(animate ? 1.8 + Double(i) * 0.35 : 0.6)
                    .animation(
                        .easeOut(duration: 1.6)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.42),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}
