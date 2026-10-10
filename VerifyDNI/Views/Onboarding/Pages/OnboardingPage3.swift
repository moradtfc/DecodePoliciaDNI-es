// OnboardingPage3.swift
// VerifyDNI — Página 3: NFC paso 1 · Prepara el documento
// Muestra el reverso real del DNI (Assets: "dniposterior")
// con overlay de enfoque pulsante en la zona del chip NFC.

import SwiftUI

struct OnboardingPage3: View {

    @State private var focusOpacity:  Double  = 0.5
    @State private var focusScale:    CGFloat = 1.0
    @State private var contentVisible         = false

    // Tamaños adaptativos para la ilustración del DNI
    private var cardW: CGFloat { ScreenSize.isSmall ? 210 : 260 }
    private var cardH: CGFloat { ScreenSize.isSmall ? 132 : 164 }

    var body: some View {
        VStack(spacing: 0) {

            Spacer(minLength: 8)

            // ── Imagen del reverso del DNI con overlays de enfoque ─────────
            ZStack(alignment: .bottom) {

                // ── 1. Imagen base ─────────────────────────────────────────
                Image("dniposterior")
                    .resizable()
                    .scaledToFit()
                    .frame(width: cardW, height: cardH)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // ── 2. Degradado oscurecedor en la zona superior ───────────
                // Guía la atención hacia la parte inferior donde está el chip.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.55),
                                Color.black.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: cardW, height: cardH)

                // ── 3. Marco de enfoque pulsante — zona inferior derecha ───
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                Color(hex: "#60A5FA").opacity(focusOpacity),
                                lineWidth: 2
                            )
                            .frame(width: 70, height: 44)
                            .scaleEffect(focusScale)
                            .padding(.trailing, 16)
                            .padding(.bottom, 12)
                    }
                }
                .frame(width: cardW, height: cardH)

                // ── 4. Etiqueta "Chip NFC" bajo el marco ──────────────────
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Chip NFC")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: "#60A5FA"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#1877FF").opacity(0.2))
                            )
                            .padding(.trailing, 22)
                            .padding(.bottom, -14)
                    }
                }
                .frame(width: cardW, height: cardH)
            }
            // ── Borde exterior del conjunto ────────────────────────────────
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(hex: "#60A5FA").opacity(0.6),
                                Color(hex: "#1877FF").opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: Color(hex: "#1877FF").opacity(0.15),
                radius: 16, x: 0, y: 8
            )
            .scaleEffect(contentVisible ? 1 : 0.85)
            .opacity(contentVisible ? 1 : 0)
            .padding(.bottom, 36)

            // ── Textos ─────────────────────────────────────────────────────
            stepBadge(number: "1", label: "PASO")

            Text("Escaneo del Reverso del documento")
                .font(.system(size: ScreenSize.isSmall ? 22 : 28,
                              weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.80)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)

            Text("Cuando se inicie la lectura NFC, ten el DNI\no TIE a mano. Asegúrate de que el documento\nestá en buen estado y sin fundas que cubran\nel chip.")
                .font(.system(size: 15))
                .foregroundColor(Color(white: 0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.top, 12)

            Spacer(minLength: ScreenSize.isSmall ? 8 : 20)

            // ── Pasos numerados ────────────────────────────────────────────
            VStack(spacing: 8) {
                numberedStep(n: 1, text: "Enfoca con la cámara el reverso del documento")
                numberedStep(n: 2, text: "Espera que se detecte el documento como válido")
                numberedStep(n: 3, text: "Sigue las instrucciones mostradas en pantalla")
            }
            .padding(.horizontal, 28)

            // ── Nota informativa ───────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#60A5FA"))
                Text("Compatible con DNIe 3.0, DNIe 4.0 y TIE con chip NFC")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.45))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 10)

            Spacer(minLength: ScreenSize.isSmall ? 12 : 36)
        }
        .onAppear {
            // Fade-in del contenido
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
                contentVisible = true
            }
            // Animación pulsante del marco de enfoque
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(
                    .easeInOut(duration: 1.1)
                    .repeatForever(autoreverses: true)
                ) {
                    focusOpacity = 1.0
                    focusScale   = 1.04
                }
            }
        }
    }

    // MARK: - Helper: paso numerado

    private func numberedStep(n: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#1877FF").opacity(0.15))
                    .frame(width: 22, height: 22)
                Text("\(n)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#60A5FA"))
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.65))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}
