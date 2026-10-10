// OnboardingPage4.swift
// VerifyDNI — Página 4: Acerca el DNI al iPhone para leer el chip NFC
// El DNI "dnicara" aparece ENCIMA del iPhone y desciende 30 pt
// para simular el gesto de apoyo contra la parte trasera del móvil.

import SwiftUI

struct OnboardingPage4: View {

    @State private var visible:   Bool    = false
    /// Desplazamiento vertical del DNI. Empieza en 0, anima hasta 30 pt.
    @State private var dniOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {

            Spacer(minLength: 8)

            // ── Ilustración ────────────────────────────────────────────────
            ZStack(alignment: .top) {

                // ── 1. DNI "dnicara" — encima del iPhone ──────────────────
                // Desciende 30 pt para simular que el usuario lo apoya en la
                // parte trasera superior del teléfono (zona antena NFC).
                Image("dnicara")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 186, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#60A5FA").opacity(0.55),
                                        Color(hex: "#1877FF").opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: Color(hex: "#1877FF").opacity(0.18),
                        radius: 14, x: 0, y: 6
                    )
                    .offset(y: dniOffset)   // 0 → 30 pt: movimiento muy visible
                    .zIndex(0)              // detrás del iPhone

                // ── 2. Ondas NFC — entre el DNI y el iPhone ───────────────
                NFCWavesView()
                    .frame(width: 100, height: 80)
                    .offset(y: 110)         // en la zona de cámara del iPhone
                    .zIndex(1)

                // ── 3. iPhone — delante del DNI ────────────────────────────
                iPhoneView
                    .offset(y: 108)         // el iPhone empieza 108 pt desde el top
                    .zIndex(2)              // siempre delante del DNI
            }
            .frame(width: ScreenSize.isSmall ? 185 : 230,
                   height: ScreenSize.isSmall ? 250 : 310)
            .scaleEffect(visible ? 1 : 0.82)
            .opacity(visible ? 1 : 0)
            .padding(.bottom, ScreenSize.isSmall ? 28 : 50)

            // ── Textos ─────────────────────────────────────────────────────
            stepBadge(number: "2", label: "PASO")

            Text("Acerca el documento al iPhone")
                .font(.system(size: ScreenSize.isSmall ? 22 : 28,
                              weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.80)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.top, 12)

            Text("Apoya el DNI en la parte trasera\ndel iPhone, cerca de la cámara,\ny mantén el contacto.")
                .font(.system(size: 15))
                .foregroundColor(Color(white: 0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 36)
                .padding(.top, 12)

            Spacer(minLength: ScreenSize.isSmall ? 16 : 40)
        }
        .onAppear {
            // Fade-in de la ilustración completa
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
                visible = true
            }
            // Movimiento del DNI: 0 → 30 pt, ida y vuelta, claramente visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    dniOffset = 30
                }
            }
        }
    }

    // MARK: - iPhone illustration

    /// Representación visual del iPhone desde el frente.
    /// Incluye cuerpo, pantalla, dynamic island, botones laterales,
    /// zona NFC destacada y el indicador home.
    private var iPhoneView: some View {
        ZStack {

            // ── Cuerpo ─────────────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#2C2C2E"), Color(hex: "#1A1A1A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 174)

            // Borde con reflejo superior
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 88, height: 174)

            // ── Pantalla ───────────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#040D1A"))
                .frame(width: 78, height: 160)

            // ── Dynamic island ─────────────────────────────────────────────
            Capsule()
                .fill(Color(hex: "#111111"))
                .frame(width: 28, height: 8)
                .offset(y: -69)

            // ── Zona NFC activa (parte superior de la pantalla) ─────────────
            // Indica visualmente dónde debe apoyarse el DNI.
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: "#1877FF").opacity(0.1))
                .frame(width: 64, height: 26)
                .offset(y: -53)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            Color(hex: "#1877FF").opacity(0.35),
                            lineWidth: 1
                        )
                        .frame(width: 64, height: 26)
                        .offset(y: -53)
                )

            // Etiqueta "NFC" dentro de la zona
            Text("NFC")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(Color(hex: "#60A5FA").opacity(0.7))
                .offset(y: -53)

            // ── Icono de la app en pantalla ────────────────────────────────
            VStack(spacing: 3) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#60A5FA"), Color(hex: "#1877FF")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("VerifyDNI")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(Color(white: 0.35))
            }
            .offset(y: 14)

            // ── Indicador home ─────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.18))
                .frame(width: 28, height: 4)
                .offset(y: 72)

            // ── Botón de encendido — lado derecho ──────────────────────────
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: "#3A3A3C"))
                .frame(width: 3.5, height: 32)
                .offset(x: 46, y: 18)

            // ── Botones de volumen — lado izquierdo ────────────────────────
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: "#3A3A3C"))
                .frame(width: 3.5, height: 22)
                .offset(x: -46, y: -12)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: "#3A3A3C"))
                .frame(width: 3.5, height: 22)
                .offset(x: -46, y: 16)
        }
    }
}
