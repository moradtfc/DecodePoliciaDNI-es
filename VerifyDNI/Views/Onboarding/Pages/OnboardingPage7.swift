// OnboardingPage7.swift
// VerifyDNI — Página 7: ¡Todo listo! Empieza a verificar

import SwiftUI

struct OnboardingPage7: View {
    @State private var visible      = false
    @State private var checkVisible = false
    @State private var arrowBounce  = false

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // ── Icono de éxito ─────────────────────────────────────────
            ZStack {
                let isSmallScreen = ScreenSize.isSmall
                Circle()
                    .fill(Color(hex: "#4ade80").opacity(0.08))
                    .frame(width: isSmallScreen ? 130 : 180,
                           height: isSmallScreen ? 130 : 180)
                Circle()
                    .fill(Color(hex: "#4ade80").opacity(0.12))
                    .frame(width: isSmallScreen ? 95 : 130,
                           height: isSmallScreen ? 95 : 130)

                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: isSmallScreen ? 50 : 66,
                           height: isSmallScreen ? 50 : 66)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#86efac"), Color(hex: "#4ade80")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(hex: "#4ade80").opacity(0.45), radius: 18)
                    .scaleEffect(checkVisible ? 1 : 0.4)
                    .opacity(checkVisible ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.25), value: checkVisible)
            }
            .scaleEffect(visible ? 1 : 0.7)
            .opacity(visible ? 1 : 0)
            .padding(.bottom, ScreenSize.isSmall ? 20 : 40)

            // ── Textos ─────────────────────────────────────────────────
            Text("¡Todo listo!")
                .font(.system(size: ScreenSize.isSmall ? 28 : 34,
                              weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.80)

            Text("Ya puedes empezar a verificar\nidentidades al instante.")
                .font(.system(size: 16))
                .foregroundColor(Color(white: 0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 36)
                .padding(.top, 12)

            Spacer()

            // ── Pista visual: flecha apuntando al botón inferior ───────
            VStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#1877FF").opacity(0.7))
                    .offset(y: arrowBounce ? 5 : 0)
                    .animation(
                        .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                        value: arrowBounce
                    )
                Text("Pulsa \"¡Empezar a verificar!\" para continuar")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.35))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
                visible = true
            }
            checkVisible = true
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(0.6)) {
                arrowBounce = true
            }
        }
    }
}
