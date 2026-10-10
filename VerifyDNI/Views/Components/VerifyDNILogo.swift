// VerifyDNILogo.swift
// VerifyDNI
// Logotipo reutilizable que reproduce exactamente el icono de la app.
// Acepta `fontSize` para escalar proporcionalmente en todas las pantallas.

import SwiftUI

struct VerifyDNILogo: View {

    var fontSize: CGFloat = 32

    @State private var verifyWidth: CGFloat = 0
    @State private var dniWidth:    CGFloat = 0

    // Azul exacto del icono: #2b7fff
    private let accent = Color(red: 43/255, green: 127/255, blue: 255/255)

    private var lineHeight: CGFloat { max(1.5, fontSize * 0.055) }
    private var lineGap:    CGFloat { fontSize * 0.18 }

    var body: some View {
        VStack(alignment: .leading, spacing: lineGap) {

            // ── "Verify" blanco + "DNI" azul ──────────────────────────
            HStack(spacing: 0) {
                Text("Verify")
                    .font(.system(size: fontSize, weight: .black, design: .default))
                    .foregroundColor(.white)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { verifyWidth = geo.size.width }
                                .onChange(of: geo.size.width) { verifyWidth = $0 }
                        }
                    )

                Text("DNI")
                    .font(.system(size: fontSize, weight: .black, design: .default))
                    .foregroundColor(accent)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { dniWidth = geo.size.width }
                                .onChange(of: geo.size.width) { dniWidth = $0 }
                        }
                    )
            }

            // ── Línea doble bajo el texto ──────────────────────────────
            // Segmento sutil bajo "Verify" + sólido bajo "DNI"
            // Siempre renderizado; frame(width: 0) es invisible hasta que
            // GeometryReader mide los anchos reales.
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: lineHeight / 2)
                    .fill(accent.opacity(0.2))
                    .frame(width: max(0, verifyWidth), height: lineHeight)
                RoundedRectangle(cornerRadius: lineHeight / 2)
                    .fill(accent)
                    .frame(width: max(0, dniWidth), height: lineHeight)
            }
        }
        // fixedSize evita que el componente se recorte en containers ajustados
        .fixedSize()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 6/255,  green: 14/255, blue: 28/255),
                Color(red: 11/255, green: 30/255, blue: 61/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 40) {
            VerifyDNILogo(fontSize: 48)
            VerifyDNILogo(fontSize: 36)
            VerifyDNILogo(fontSize: 22)
        }
    }
    .preferredColorScheme(.dark)
}
