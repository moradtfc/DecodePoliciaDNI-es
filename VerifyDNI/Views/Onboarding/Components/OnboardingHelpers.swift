// OnboardingHelpers.swift
// VerifyDNI
// Funciones auxiliares reutilizadas entre las páginas del onboarding.

import SwiftUI

/// Badge numerado de paso — reutilizado por las páginas de proceso NFC y QR.
func stepBadge(number: String, label: String) -> some View {
    HStack(spacing: 6) {
        ZStack {
            Circle()
                .fill(Color(hex: "#1877FF"))
                .frame(width: 24, height: 24)
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color(hex: "#60A5FA"))
            .kerning(1.2)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(
        Capsule()
            .fill(Color(hex: "#1877FF").opacity(0.1))
            .overlay(Capsule().strokeBorder(Color(hex: "#1877FF").opacity(0.2), lineWidth: 1))
    )
}
