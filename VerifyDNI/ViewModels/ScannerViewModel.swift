// ScannerViewModel.swift
// VerifyDNI
//
// Gestiona el ciclo de vida del escaneo QR: captura → parse → resultado.
// isProcessing evita llamadas duplicadas a MiDNIParser si llegan
// varios frames consecutivos del mismo QR.

import Foundation
import AVFoundation
import Combine

// MARK: - ScannerViewModel

@MainActor
final class ScannerViewModel: ObservableObject {

    // MARK: - ScanState

    enum ScanState {
        case scanning               // Esperando un QR válido.
        case processing             // QR recibido, MiDNIParser en marcha.
        case done(MiDNIVerificationResult)  // Verificación completada.
    }

    // MARK: Estado publicado

    @Published var scanState: ScanState = .scanning
    @Published var torchOn: Bool = false

    // MARK: Privado

    /// Bloquea nuevos frames mientras se procesa uno.
    /// Expuesto con `private(set)` para que `BarcodeScannerRepresentable`
    /// pueda observarlo y resetear el flag interno del VC.
    private(set) var isProcessing: Bool = false

    // MARK: - Computed

    /// `true` cuando el escáner está activo y listo para leer.
    var isActivelyScanning: Bool {
        guard case .scanning = scanState else { return false }
        return !isProcessing
    }

    // MARK: - Acciones

    /// Recibe los bytes crudos del QR detectado por ML Kit y orquesta la verificación.
    /// - Parameter data: `barcode.rawData` (binario, NO rawValue).
    func processQRData(_ data: Data) async {
        guard !isProcessing else { return }
        isProcessing = true
        scanState = .processing

        do {
            let result = try await MiDNIParser.parse(data)
            scanState = .done(result)
            // NO enviar aquí — el envío lo controla el botón
            // "Enviar datos al panel" en ResultView para evitar
            // doble registro en la tabla verifications.

        } catch let error as MiDNIError {
            let fail = MiDNIVerificationResult.failure(error)
            scanState = .done(fail)

        } catch {
            let fail = MiDNIVerificationResult.failure(.unknownError(error.localizedDescription))
            scanState = .done(fail)
        }

        isProcessing = false
    }

    /// Restablece el estado al inicio del ciclo de escaneo.
    /// Llamar desde ResultView → "Escanear de nuevo".
    func resetScanner() {
        isProcessing = false
        scanState = .scanning
    }

    // MARK: - Linterna

    /// Activa o desactiva la linterna del dispositivo.
    func toggleTorch() {
        torchOn.toggle()
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = torchOn ? .on : .off
        device.unlockForConfiguration()
    }
}
