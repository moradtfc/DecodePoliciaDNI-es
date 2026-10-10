// CardSimuladoView.swift
// VerifyDNI
// Simula una card de acción del HomeView de la app.
// Reutilizado en OnboardingPage2 (NFC) y OnboardingPage5 (QR).

import SwiftUI

struct CardSimuladoView: View {
    let icon: String
    let titulo: String
    let activo: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        (activo
                            ? Color(hex: "#1877FF")
                            : Color(white: 0.2)
                        ).opacity(0.15)
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(
                        activo
                            ? Color(hex: "#60A5FA")
                            : Color(white: 0.4)
                    )
            }
            Text(titulo)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(
                    activo ? .white : Color(white: 0.35)
                )
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(
                    Color(white: activo ? 0.5 : 0.2)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(activo ? 0.07 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(activo ? 0.12 : 0.05),
                            lineWidth: 1
                        )
                )
        )
        .frame(width: 260)
    }
}
