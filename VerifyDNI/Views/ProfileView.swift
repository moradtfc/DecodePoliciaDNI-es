// ProfileView.swift
// VerifyDNI
// Pantalla de perfil.
// Segunda tab de MainTabView.

import SwiftUI

struct ProfileView: View {

    @State private var showOnboarding: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Fondo base
            Color(hex: "#040D1A").ignoresSafeArea()

            // Patrón guilloché — opacidad reducida
            guillochBackground
                .opacity(0.4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ── Título ─────────────────────────────────────────
                    Text("Perfil")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // ── Avatar + nombre ────────────────────────────────
                    avatarCard

                    // ── Info de la app ─────────────────────────────────
                    appSection

                    // ── Recursos ───────────────────────────────────────
                    resourcesSection

                    // ── Branding ───────────────────────────────────────
                    brandingSection

                    // Espacio para el tab bar flotante
                    Spacer(minLength: ScreenSize.isSmall ? 90 : 120)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Avatar Card

    private var avatarCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#1877FF").opacity(0.15))
                    .frame(width: 80, height: 80)
                Circle()
                    .strokeBorder(
                        Color(hex: "#1877FF").opacity(0.3),
                        lineWidth: 1.5
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Color(hex: "#60A5FA"))
            }

            Text("VerifyDNI")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text("Validador de identidad")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .glassCard(cornerRadius: 20)
        .padding(.horizontal, 20)
    }

    // ── Sección app ────────────────────────────────────────────────────

    private var appSection: some View {
        VStack(spacing: 1) {
            appInfoRow(
                icon: "checkmark.shield",
                label: "Versión",
                value: appVersion
            )
            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.leading, 52)
            appInfoRow(
                icon: "doc.text",
                label: "Certificado MiDNI",
                value: "Policía Nacional · Activo",
                valueColor: Color(hex: "#4ade80")
            )
        }
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 20)
    }

    private func appInfoRow(
        icon: String,
        label: String,
        value: String,
        valueColor: Color = Color(white: 0.75)
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: "#1877FF").opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#60A5FA"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.4))
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(valueColor)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.80)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // ── Sección recursos ───────────────────────────────────────────────

    private var resourcesSection: some View {
        VStack(spacing: 1) {
            Button {
                showOnboarding = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(hex: "#1877FF").opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: "play.circle")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "#60A5FA"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ver tutorial")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(white: 0.75))
                        Text("Repasa cómo usar VerifyDNI")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.38))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(white: 0.25))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 20)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "1.0"
    }

    // MARK: - Branding

    private var brandingSection: some View {
        VStack(spacing: 8) {
            VerifyDNILogo(fontSize: 26)
            Text("v\(appVersion) · VerifyDNI")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(white: 0.3))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
    }

    // MARK: - Guilloché background

    private var guillochBackground: some View {
        Canvas { context, size in
            let lineCount  = size.height < 700 ? 25 : 40
            let centerX    = size.width  * 0.5
            let centerY    = size.height * 0.35
            for i in 0..<lineCount {
                let progress  = Double(i) / Double(lineCount)
                let radius    = progress * size.width * 1.2
                let amplitude = 8.0  + progress * 12.0
                let frequency = 6.0  + progress * 2.0
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
                    with: .color(Color(hex: "#1877FF").opacity(0.03 + progress * 0.02)),
                    lineWidth: 0.5
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass Card modifier (reutilizable en el proyecto)

private extension View {
    func glassCard(cornerRadius: CGFloat) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
