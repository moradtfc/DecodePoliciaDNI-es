// OnboardingPage6.swift
// VerifyDNI — Página 6: QR · Cómo escanear el QR MiDNI

import SwiftUI

struct OnboardingPage6: View {
    @State private var visible = false

    var body: some View {
        VStack(spacing: 0) {

            Spacer(minLength: 8)

            // ── Ilustración: pantalla con QR siendo escaneado ──────────
            ZStack {
                // Fondo de pantalla del cliente simulado
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "#0E1E35"))
                    .frame(width: 190, height: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color(hex: "#1877FF").opacity(0.25), lineWidth: 1)
                    )

                // Pantalla interior con QR
                VStack(spacing: 8) {
                    Text("MiDNI")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(white: 0.5))
                    // QR simulado con cuadrícula de puntos
                    QRCodeSimView()
                        .frame(width: 110, height: 110)
                    Text("Código válido por 2 min.")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color(white: 0.35))
                }
                .frame(width: 168, height: 196)
                .background(Color(hex: "#040D1A"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Marco de escaneo animado sobre el QR
                MRZScanFrameView(cornerLength: 18, cornerRadius: 5, lineWidth: 2.5,
                                 color: Color(hex: "#60A5FA"))
                    .frame(width: 118, height: 118)
            }
            .scaleEffect(visible ? 1 : 0.85)
            .opacity(visible ? 1 : 0)
            .padding(.bottom, 36)

            // ── Textos ─────────────────────────────────────────────────
            Text("¿Cómo escanear el QR?")
                .font(.system(size: ScreenSize.isSmall ? 24 : 30,
                              weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.80)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)

            Spacer(minLength: ScreenSize.isSmall ? 8 : 20)

            // ── Pasos ──────────────────────────────────────────────────
            VStack(spacing: 8) {
                numberedStep(n: 1, text: "El cliente abre MiDNI y genera su QR")
                numberedStep(n: 2, text: "Pulsa 'Escanear QR MiDNI' en VerifyDNI")
                numberedStep(n: 3, text: "Apunta la cámara al QR del cliente")
                numberedStep(n: 4, text: "El resultado aparece en menos de 2 segundos")
            }
            .padding(.horizontal, 28)

            // ── Nota ───────────────────────────────────────────────────
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#FBBF24"))
                Text("El QR de MiDNI caduca a los 2 minutos. Si falla, pide al cliente que genere uno nuevo.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.45))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 10)

            Spacer(minLength: ScreenSize.isSmall ? 12 : 36)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
                visible = true
            }
        }
    }

    // MARK: - Helpers

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

// MARK: - QR simulado (cuadrícula de módulos)

private struct QRCodeSimView: View {
    // Patrón simplificado de 11×11 módulos (0=blanco, 1=negro)
    private let grid: [[Int]] = [
        [1,1,1,1,1,1,1,0,1,1,1],
        [1,0,0,0,0,0,1,0,0,1,0],
        [1,0,1,1,1,0,1,0,1,0,1],
        [1,0,1,1,1,0,1,0,0,1,0],
        [1,0,0,0,0,0,1,0,1,1,1],
        [1,1,1,1,1,1,1,0,1,0,1],
        [0,0,0,0,0,0,0,0,0,1,0],
        [1,0,1,1,0,1,0,1,1,0,1],
        [1,1,0,1,0,0,1,1,0,1,1],
        [0,1,1,0,1,0,0,0,1,0,0],
        [1,1,1,1,1,1,1,0,0,1,1],
    ]

    var body: some View {
        GeometryReader { geo in
            let cell = geo.size.width / CGFloat(grid[0].count)
            Canvas { context, _ in
                for row in 0..<grid.count {
                    for col in 0..<grid[row].count {
                        let rect = CGRect(
                            x: CGFloat(col) * cell,
                            y: CGFloat(row) * cell,
                            width: cell,
                            height: cell
                        )
                        let color: Color = grid[row][col] == 1
                            ? Color(white: 0.88)
                            : Color(hex: "#040D1A")
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .background(Color(hex: "#040D1A"))
    }
}
