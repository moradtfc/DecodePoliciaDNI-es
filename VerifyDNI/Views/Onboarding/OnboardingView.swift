// OnboardingView.swift
// VerifyDNI
// Contenedor principal del onboarding de 7 páginas.
// Se muestra una única vez tras el primer inicio de sesión.
// El usuario puede avanzar con el botón, deslizar o saltar.

import SwiftUI

struct OnboardingView: View {
    /// Callback al completar o saltar el onboarding.
    var onFinish: () -> Void

    @State private var currentPage = 0

    /// Número total de páginas — actualizar aquí para futuros cambios.
    private let totalPages = 7

    var body: some View {
        ZStack {
            // Fondo base
            Color(hex: "#040D1A").ignoresSafeArea()

            // Patrón guilloché tenue
            guillochBackground
                .opacity(0.3)

            // Gradiente radial sutil en esquina superior
            RadialGradient(
                colors: [Color(hex: "#1877FF").opacity(0.08), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Cabecera: logo + skip / indicador ─────────────────
                VStack(spacing: 14) {
                    HStack(alignment: .center) {
                        VerifyDNILogo(fontSize: 20)
                        Spacer()
                        if currentPage < totalPages - 1 {
                            Button("Saltar") { completeOnboarding() }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(white: 0.4))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.white.opacity(0.05)))
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }
                    PageIndicatorView(total: totalPages, current: currentPage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 10)

                // ── Páginas ────────────────────────────────────────────
                TabView(selection: $currentPage) {
                    OnboardingPage1().tag(0)
                    OnboardingPage2().tag(1)   // NFC — dónde pulsar
                    OnboardingPage3().tag(2)   // NFC paso 1 — prepara el doc
                    OnboardingPage4().tag(3)   // NFC paso 2 — acerca al iPhone
                    OnboardingPage5().tag(4)   // QR — dónde pulsar
                    OnboardingPage6().tag(5)   // QR — proceso de escaneo
                    OnboardingPage7().tag(6)   // ¡Todo listo!
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.85),
                    value: currentPage
                )

                // ── Botón Siguiente / Empezar ──────────────────────────
                Button {
                    if currentPage < totalPages - 1 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentPage < totalPages - 1
                             ? "Siguiente"
                             : "¡Empezar a verificar!")
                            .font(.system(size: 16, weight: .bold))
                            .minimumScaleFactor(0.85)
                            .allowsTightening(true)
                            .lineLimit(1)
                        if currentPage < totalPages - 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: ScreenSize.isSmall ? 48 : 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#2D8FFF"), Color(hex: "#1877FF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: Color(hex: "#1877FF").opacity(0.4),
                                radius: 12, y: 6
                            )
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
        .preferredColorScheme(.dark)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -50, currentPage < totalPages - 1 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            currentPage += 1
                        }
                    } else if value.translation.width > 50, currentPage > 0 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            currentPage -= 1
                        }
                    }
                }
        )
    }

    // MARK: - Completion

    private func completeOnboarding() {
        UserDefaults.standard.hasCompletedOnboarding = true
        onFinish()
    }

    // MARK: - Background

    private var guillochBackground: some View {
        Canvas { context, size in
            let lineCount  = 30
            let centerX    = size.width  * 0.5
            let centerY    = size.height * 0.3
            for i in 0..<lineCount {
                let progress  = Double(i) / Double(lineCount)
                let radius    = progress * size.width * 1.1
                let amplitude = 8.0  + progress * 10.0
                let frequency = 5.0  + progress * 2.0
                var path      = Path()
                for j in 0...200 {
                    let angle = (Double(j) / 200.0) * .pi * 2
                    let wave  = amplitude * sin(angle * frequency + progress * .pi)
                    let x     = centerX + (radius + wave) * cos(angle)
                    let y     = centerY + (radius + wave) * sin(angle)
                    if j == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else       { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                path.closeSubpath()
                context.stroke(
                    path,
                    with: .color(Color(hex: "#1877FF").opacity(0.025 + progress * 0.015)),
                    lineWidth: 0.5
                )
            }
        }
        .ignoresSafeArea()
    }
}
