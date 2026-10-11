// VerifyDNIApp.swift
// VerifyDNI
// Punto de entrada de la aplicación.
// Flujo: LaunchScreenView → MainTabView

import SwiftUI

@main
struct VerifyDNIApp: App {

    @StateObject private var wsManager = WebSocketManager.shared

    /// Controla la pantalla de arranque animada (2s al inicio de cada sesión).
    @State private var isLaunching: Bool = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isLaunching {
                    // ── Pantalla de arranque animada ───────────────────
                    LaunchScreenView {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            isLaunching = false
                        }
                    }
                    .transition(.opacity)

                } else {
                    MainTabView()
                        .environmentObject(wsManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: isLaunching)
            .task {
                // Pre-cargar certificado MiDNI en background
                Task {
                    try? await CertificateManager.shared.loadCertificate()
                }
            }
        }
    }
}
