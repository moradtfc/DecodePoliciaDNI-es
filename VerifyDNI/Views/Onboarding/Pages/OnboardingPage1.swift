// OnboardingPage1.swift
// VerifyDNI — Página 1: Bienvenida
// Layout adaptativo: compacto en iPhone SE (≤667 pt), holgado en pantallas grandes.

import SwiftUI

struct OnboardingPage1: View {

    @State private var cardVisible:  Bool = false
    @State private var logoVisible:  Bool = false
    @State private var pillsVisible: Bool = false

    // Pantallas ≤667 pt de alto (SE 1ª/2ª gen, iPhone 8…)
    private var compact: Bool {
        ScreenSize.isSmall
    }

    private let pills: [(icon: String, label: String)] = [
        ("bolt.fill",         "Verificación en segundos"),
        ("lock.shield.fill",  "Datos seguros"),
        ("wave.3.right",      "Lectura NFC"),
        ("qrcode.viewfinder", "Lectura DNI Digital"),
    ]

    var body: some View {
        VStack(spacing: 0) {

            Spacer(minLength: compact ? 4 : 12)

            // ── Ilustración DNI (movida desde Page3) ──────────────────────
            dniCardIllustration
                .scaleEffect(cardVisible ? 1.0 : 0.86)
                .opacity(cardVisible ? 1.0 : 0)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.7).delay(0.05),
                    value: cardVisible
                )
                .padding(.bottom, compact ? 14 : 22)

            // ── Logo principal ─────────────────────────────────────────────
            VerifyDNILogo(fontSize: compact ? 30 : 38)
                .scaleEffect(logoVisible ? 1.0 : 0.82)
                .opacity(logoVisible ? 1.0 : 0)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.7).delay(0.15),
                    value: logoVisible
                )
                .padding(.bottom, compact ? 6 : 10)

            // ── Subtítulo con bandera española ────────────────────────────
            HStack(spacing: 7) {
                // Franjas de la bandera de España (rojo / amarillo / rojo)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(hex: "#AA151B"))
                        .frame(width: 22, height: 5)
                    Rectangle()
                        .fill(Color(hex: "#F1BF00"))
                        .frame(width: 22, height: 8)
                    Rectangle()
                        .fill(Color(hex: "#AA151B"))
                        .frame(width: 22, height: 5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)

                Text("Documentos Españoles")
                    .font(.system(size: compact ? 13 : 15, weight: .medium))
                    .foregroundColor(Color(white: 0.55))
            }
            .opacity(logoVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.25), value: logoVisible)

            // ── Descripción ────────────────────────────────────────────────
            Text("Verifica la identidad de tus clientes en segundos mediante lectura NFC del chip del DNI físico y decodificado del DNI digital español.")
                .font(.system(size: compact ? 12 : 14))
                .foregroundColor(Color(white: 0.42))
                .multilineTextAlignment(.center)
                .lineSpacing(compact ? 2 : 4)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, compact ? 24 : 36)
                .padding(.top, compact ? 6 : 12)
                .opacity(logoVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: logoVisible)

            Spacer(minLength: compact ? 10 : 20)

            // ── Pills de características ───────────────────────────────────
            VStack(spacing: compact ? 7 : 10) {
                ForEach(Array(pills.enumerated()), id: \.offset) { index, pill in
                    HStack(spacing: 12) {
                        Image(systemName: pill.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 43/255, green: 127/255, blue: 255/255))
                            .frame(width: 28)
                        Text(pill.label)
                            .font(.system(size: compact ? 14 : 15, weight: .medium))
                            .foregroundColor(Color(white: 0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .allowsTightening(true)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#4ade80"))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, compact ? 9 : 13)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .opacity(pillsVisible ? 1 : 0)
                    .offset(y: pillsVisible ? 0 : 14)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.75)
                        .delay(0.45 + Double(index) * 0.08),
                        value: pillsVisible
                    )
                }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: compact ? 8 : 32)
        }
        .onAppear {
            cardVisible  = true
            logoVisible  = true
            pillsVisible = true
        }
    }

    // MARK: - Ilustración DNI (movida desde Page3)
    // Tarjeta sintética que representa el anverso del DNI físico.

    private var dniCardIllustration: some View {
        let cardW: CGFloat = compact ? 206 : 240
        let cardH: CGFloat = compact ? 128 : 152
        let haloW: CGFloat = compact ? 226 : 260
        let haloH: CGFloat = compact ? 146 : 170

        return ZStack {
            // Halo exterior
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#1877FF").opacity(0.06))
                .frame(width: haloW, height: haloH)

            // Tarjeta DNI
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#0D2040"), Color(hex: "#0A1628")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: cardW, height: cardH)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(hex: "#1877FF").opacity(0.3), lineWidth: 1)
                )
                .overlay(dniCardContent(w: cardW, h: cardH))
                .shadow(color: Color(hex: "#1877FF").opacity(0.18), radius: 16, y: 8)
        }
    }

    private func dniCardContent(w: CGFloat, h: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                // Chip dorado simulado
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "#FFD700").opacity(0.6))
                    .frame(width: 24, height: 18)
                // Líneas de texto simuladas
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(i == 0 ? 0.18 : 0.10))
                            .frame(width: i == 0 ? 80 : 56, height: 4)
                    }
                }
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(Color(hex: "#60A5FA").opacity(0.55))
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer()

            // Zona MRZ
            VStack(spacing: 3) {
                mrzLine("IDESP<<GARCIA<LOPEZ<JUAN<<<<<<<<<")
                mrzLine("12345678A8ESP9001011M3001010<<<<<")
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private func mrzLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 6.5, weight: .medium, design: .monospaced))
            .foregroundColor(Color(white: 0.35))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
