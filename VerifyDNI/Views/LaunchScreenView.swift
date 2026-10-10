// LaunchScreenView.swift
// VerifyDNI
// Primera pantalla animada al ejecutar la app.
// El logo es visible desde el primer frame (sin opacity inicial = 0).
// Secuencia: logo inmediato → loader fade-in → espera 2.4s → fade-out → onFinished()

import SwiftUI

struct LaunchScreenView: View {

    /// Llamado al completar la animación de salida (~2.9s desde el inicio).
    var onFinished: () -> Void

    @State private var loaderVisible: Bool = false
    @State private var isFadingOut:   Bool = false

    private let accent = Color(red: 43/255, green: 127/255, blue: 255/255)

    var body: some View {
        ZStack {
            // Fondo — mismo gradiente que el fondo de la app
            LinearGradient(
                colors: [
                    Color(red: 6/255,  green: 14/255, blue: 28/255),   // #060e1c
                    Color(red: 11/255, green: 30/255, blue: 61/255)    // #0b1e3d
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                // Logo principal — siempre visible desde el primer frame
                VerifyDNILogo(fontSize: 48)

                // Loader — aparece poco después con fade
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(accent)
                    .scaleEffect(0.9)
                    .opacity(loaderVisible ? 1 : 0)
            }
            // Fade-out de todo el contenido al final
            .opacity(isFadingOut ? 0 : 1)
            .scaleEffect(isFadingOut ? 0.95 : 1.0)
        }
        .preferredColorScheme(.dark)
        // .task garantiza que el bloque async se ejecuta en el contexto del actor principal
        // y que la vista ya está insertada en la jerarquía antes de modificar el estado.
        .task { await runSequence() }
    }

    // MARK: - Sequence

    private func runSequence() async {
        // Pequeña pausa para que la vista esté completamente en la jerarquía
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Loader aparece con suavidad
        withAnimation(.easeOut(duration: 0.35)) {
            loaderVisible = true
        }

        // Mantener el loader visible al menos 2.4 s (total desde inicio: ~2.5 s)
        try? await Task.sleep(nanoseconds: 2_400_000_000) // 2.4s

        // Fade-out del conjunto
        withAnimation(.easeIn(duration: 0.4)) {
            isFadingOut = true
        }

        // Esperar a que termine la animación de salida
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s

        onFinished()
    }
}

#Preview {
    LaunchScreenView(onFinished: {})
}
