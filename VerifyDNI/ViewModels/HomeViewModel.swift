// HomeViewModel.swift
// VerifyDNI
//
// ViewModel de HomeView. Observa WebSocketManager
// y expone el estado listo para consumir en la vista.

import Foundation
import Combine

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Estado publicado

    /// Estado actual del canal Realtime (se sincroniza con WebSocketManager).
    @Published var connectionState: WebSocketManager.ConnectionState = .disconnected

    /// Último escaneo registrado en esta sesión.
    @Published var lastScan: LastScan?

    // MARK: - LastScan

    struct LastScan {
        let timestamp: Date
        let wasValid: Bool
        let isExpired: Bool
        let documentTypeLabel: String   // "DNI", "TIE" o "Pasaporte"
        let personName: String?

        /// Texto de estado para mostrar en el footer.
        var statusText: String {
            guard wasValid else { return "Inválida" }
            return isExpired ? "\(documentTypeLabel) caducado" : "Válida"
        }

        /// Texto relativo al tiempo transcurrido, p.ej. "hace 3 seg".
        var elapsedText: String {
            let seconds = Int(Date().timeIntervalSince(timestamp))
            switch seconds {
            case 0..<60:  return "hace \(seconds) seg"
            case 60..<3600:
                let mins = seconds / 60
                return "hace \(mins) min"
            default:
                let hours = seconds / 3600
                return "hace \(hours) h"
            }
        }
    }

    // MARK: - Propiedades

    /// Nombre del establecimiento (valor por defecto, app sin login).
    let establishmentName: String = "Mi establecimiento"

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // Leer estado inicial.
        connectionState = WebSocketManager.shared.connectionState

        // Suscribirse a futuros cambios de WebSocketManager.
        WebSocketManager.shared.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)
    }

    // MARK: - Acciones

    /// Intenta reconectar el canal Realtime.
    func refreshConnection() async {
        await WebSocketManager.shared.reconnect()
    }

    /// Registra el resultado de un escaneo para mostrarlo en el footer.
    func recordScan(_ result: MiDNIVerificationResult) {
        lastScan = LastScan(
            timestamp: result.verificationTimestamp,
            wasValid: result.isValid,
            isExpired: result.isDocumentExpired,
            documentTypeLabel: result.documentTypeLabel,
            personName: result.fullName
        )
    }
}
