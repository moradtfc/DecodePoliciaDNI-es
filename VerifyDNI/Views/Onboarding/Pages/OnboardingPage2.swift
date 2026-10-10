// OnboardingPage2.swift
// VerifyDNI — Página 2: Dónde pulsar para iniciar la lectura NFC

import SwiftUI

struct OnboardingPage2: View {
    @State private var visible       = false
    @State private var arrowOffset: CGFloat = 0
    @State private var pulseOpacity: Double = 0.4

    var body: some View {
        VStack(spacing: 0) {

            Spacer(minLength: 8)

            // ── Ilustración: pantalla HomeView simulada ────────────────
            ZStack(alignment: .center) {
                // Marco de teléfono
                phoneFrame
                    .frame(width: 220, height: 310)

                // Contenido de la pantalla dentro del teléfono
                VStack(spacing: 0) {
                    // Barra de título simulada
                    HStack {
                        Text("VerifyDNI")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#60A5FA"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    // Cards
                    VStack(spacing: 8) {
                        CardSimuladoView(
                            icon: "qrcode.viewfinder",
                            titulo: "Escanear QR MiDNI",
                            activo: false
                        )
                        .opacity(0.35)
                        .scaleEffect(0.97)

                        CardSimuladoView(
                            icon: "wave.3.right.circle",
                            titulo: "Leer chip del DNI o NIE físico",
                            activo: true
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    Color(hex: "#60A5FA").opacity(pulseOpacity),
                                    lineWidth: 2
                                )
                        )
                    }
                    .padding(.horizontal, 10)

                    Spacer()
                }
                .frame(width: 200, height: 280)
                .background(Color(hex: "#040D1A"))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .offset(y: 6)
            }
            .overlay(
                // Flecha animada a la derecha de la card NFC
                HStack(spacing: 0) {
                    Spacer()
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#60A5FA"))
                        .offset(x: arrowOffset)
                        .shadow(color: Color(hex: "#60A5FA").opacity(0.5), radius: 6)
                }
                .padding(.trailing, -2)
                .offset(y: 30)
            )
            .scaleEffect(visible ? 1 : 0.85)
            .opacity(visible ? 1 : 0)
            .padding(.bottom, 36)

            // ── Textos ─────────────────────────────────────────────────
            Text("Escaneo NFC")
                .font(.system(size: ScreenSize.isSmall ? 24 : 30,
                              weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.80)
                .padding(.horizontal, 32)

            Text("En la pantalla de inicio encontrarás\nla opción para leer el chip del documento.\nPúlsala cuando quieras verificar un\ndocumento físico.")
                .font(.system(size: 15))
                .foregroundColor(Color(white: 0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 36)
                .padding(.top, 12)

            Spacer(minLength: ScreenSize.isSmall ? 8 : 20)

            // ── Items informativos ─────────────────────────────────────
            VStack(spacing: 8) {
                infoRow(icon: "wave.3.right.circle",
                        iconColor: Color(hex: "#60A5FA"),
                        text: "Presiona la opción 'Leer chip'")
                infoRow(icon: "hand.tap",
                        iconColor: Color(hex: "#60A5FA"),
                        text: "Comienza el proceso de verificación y lectura")
                infoRow(icon: "checkmark.shield",
                        iconColor: Color(hex: "#60A5FA"),
                        text: "Valida los resultados obtenidos")
            }
            .padding(.horizontal, 28)

            Spacer(minLength: ScreenSize.isSmall ? 16 : 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
                visible = true
            }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(0.3)) {
                arrowOffset = -8
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.2)) {
                pulseOpacity = 1.0
            }
        }
    }

    // MARK: - Helpers

    private var phoneFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(hex: "#0E1E35"))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color(hex: "#1877FF").opacity(0.3), lineWidth: 1.5)
                )
            // Dynamic island
            Capsule()
                .fill(Color(hex: "#040D1A"))
                .frame(width: 52, height: 12)
                .offset(y: -130)
        }
    }

    private func infoRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.65))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}
