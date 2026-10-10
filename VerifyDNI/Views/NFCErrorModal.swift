// NFCErrorModal.swift
// VerifyDNI
// Modal de error para la lectura NFC del chip del DNI.
// Respeta el sistema de diseño de la app: fondo #040D1A, tipografía y colores semánticos.

import SwiftUI

struct NFCErrorModal: View {

    let error:         NFCViewModel.NFCReadError
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {

            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(white: 0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 24)

            // Icono de error
            ZStack {
                Circle()
                    .fill(Color(hex: "#ef4444").opacity(0.10))
                    .frame(width: 72, height: 72)
                Circle()
                    .strokeBorder(
                        Color(hex: "#ef4444").opacity(0.25),
                        lineWidth: 1
                    )
                    .frame(width: 72, height: 72)
                Image(systemName: "wave.3.right.circle")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(Color(hex: "#f87171"))
                // Badge de error superpuesto
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#f87171"))
                    .offset(x: 14, y: -14)
            }
            .padding(.bottom, 16)

            // Título
            Text(error.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.80)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            // Descripción
            Text(error.message)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
                .padding(.bottom, 16)

            // Instrucción accionable
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#facc15"))
                Text(error.instruction)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#facc15"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(hex: "#facc15").opacity(0.08)))
            .padding(.horizontal, 24)
            .padding(.bottom, 28)

            // Acciones
            VStack(spacing: 8) {
                if error.canRetry {
                    Button {
                        isPresented = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Reintentar")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: ScreenSize.isSmall ? 48 : 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(hex: "#ef4444").opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            Color(hex: "#ef4444").opacity(0.35),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .padding(.horizontal, 24)
                }

                Button {
                    isPresented = false
                } label: {
                    Text("Usar escáner QR en su lugar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#60A5FA"))
                }
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#040D1A"))
    }
}
