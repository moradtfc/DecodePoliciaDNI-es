// WebSocketManager.swift
// VerifyDNI
//
// Gestiona la conexión Supabase Realtime v2 para emitir verificaciones en tiempo real.
// Cada sesión de usuario tiene un canal "verification:<userId>".
//
// BUGS CORREGIDOS (supabase-swift 2.43.0):
//   1. channel() es síncrono — eliminado `await` erróneo
//   2. subscribe() (deprecated) tragaba errores → reemplazado por subscribeWithError()
//   3. [String: AnyJSON] resolvía al overload no-throwing de broadcast() →
//      reemplazado por VerificationPayload: Encodable para forzar el overload
//      correcto (async throws) y garantizar serialización JSON predecible

import Foundation
import Combine
import Supabase
import UIKit

// MARK: - WebSocketManager

@MainActor
final class WebSocketManager: ObservableObject {

    // MARK: - ConnectionState

    public enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
    }

    // MARK: Singleton

    static let shared = WebSocketManager()
    private init() {}

    // MARK: Estado publicado

    /// Estado actual del canal Realtime.
    @Published private(set) var connectionState: ConnectionState = .disconnected

    /// `true` cuando el canal está suscrito y listo para emitir.
    var isConnected: Bool { connectionState == .connected }

    // MARK: Privado

    private var channel: RealtimeChannelV2?
    private var currentAccountId: String?

    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Conexión

    /// Abre el canal Realtime para el `accountId` indicado.
    /// Usa `subscribeWithError()` para detectar fallos de suscripción.
    func connect(accountId: String) async {
        #if DEBUG
        print("[WebSocketManager] connect() — accountId: \(accountId)")
        print("[WebSocketManager] estado previo: \(connectionState), currentAccountId: \(String(describing: currentAccountId))")
        #endif

        if currentAccountId == accountId, connectionState == .connected {
            #if DEBUG
            print("[WebSocketManager] Ya conectado al mismo canal — sin cambios")
            #endif
            return
        }

        disconnect()
        connectionState = .connecting

        let channelName = "\(AppConfig.realtimeChannelPrefix):\(accountId)"

        #if DEBUG
        print("[WebSocketManager] Creando canal '\(channelName)'…")
        #endif

        // FIX 1: channel() es síncrono — no necesita await
        // FIX 2: acknowledgeBroadcasts = true para confirmación de envío
        let ch = client.realtimeV2.channel(channelName) { options in
            options.broadcast.acknowledgeBroadcasts = true
        }

        do {
            // FIX 3: subscribeWithError() lanza si la suscripción falla
            // (subscribe() deprecated la tragaba silenciosamente)
            try await ch.subscribeWithError()
            channel = ch
            currentAccountId = accountId
            connectionState = .connected
            #if DEBUG
            print("[WebSocketManager] ✓ Canal '\(channelName)' suscrito")
            print("[WebSocketManager] connectionState: \(connectionState)")
            #endif
        } catch {
            connectionState = .disconnected
            channel = nil
            currentAccountId = nil
            #if DEBUG
            print("[WebSocketManager] ✗ subscribeWithError() falló: \(error)")
            #endif
        }
    }

    // MARK: - Reconexión

    /// Reconecta con el último `accountId` conocido.
    func reconnect() async {
        guard let accountId = currentAccountId else {
            #if DEBUG
            print("[WebSocketManager] reconnect() — sin accountId disponible")
            #endif
            return
        }
        await connect(accountId: accountId)
    }

    // MARK: - Desconexión

    /// Cierra el canal Realtime activo.
    func disconnect() {
        guard let ch = channel else {
            connectionState = .disconnected
            return
        }
        Task { await ch.unsubscribe() }
        channel = nil
        currentAccountId = nil
        connectionState = .disconnected
        #if DEBUG
        print("[WebSocketManager] Canal desconectado")
        #endif
    }

    // MARK: - Emit verificación

    /// Emite un evento `dni_verified` por Realtime Broadcast Y persiste
    /// el resultado en la tabla `verifications` de Supabase.
    ///
    /// Doble canal de entrega:
    ///   • Broadcast  → panel web conectado en tiempo real (peer-to-peer, efímero)
    ///   • DB insert  → registro persistente, visible en Table Editor y
    ///                  mediante Postgres Changes en el panel web
    func sendVerification(_ result: MiDNIVerificationResult) async {
        #if DEBUG
        print("[WebSocketManager] sendVerification() llamado")
        print("[WebSocketManager] channel: \(channel == nil ? "nil ❌" : "OK ✓")")
        print("[WebSocketManager] connectionState: \(connectionState)")
        #endif

        let payload = VerificationPayload(from: result)

        // ── 1. Broadcast Realtime (requiere canal activo) ─────────────────────
        if let ch = channel, connectionState == .connected {
            do {
                try await ch.broadcast(event: "dni_verified", message: payload)
                #if DEBUG
                print("[WebSocketManager] ✓ Broadcast 'dni_verified' enviado — isValid: \(result.isValid)")
                #endif
            } catch {
                #if DEBUG
                print("[WebSocketManager] ✗ broadcast() falló: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("[WebSocketManager] ⚠️ Sin canal activo — solo persistencia en DB")
            #endif
        }

        // ── 2. Persistir en tabla `verifications` ─────────────────────────────
        // Garantiza que el panel web recibe los datos aunque el broadcast
        // llegue cuando no haya receptor conectado.
        guard let accountId = currentAccountId else {
            #if DEBUG
            print("[WebSocketManager] ⚠️ Sin accountId — omitiendo insert en DB")
            #endif
            return
        }

        do {
            try await client
                .from(AppConfig.verificationsTable)
                .insert(DBVerificationRow(accountId: accountId, payload: payload))
                .execute()
            #if DEBUG
            print("[WebSocketManager] ✓ Verificación persistida en tabla '\(AppConfig.verificationsTable)'")
            #endif
        } catch {
            #if DEBUG
            print("[WebSocketManager] ✗ Insert en DB falló: \(error)")
            #endif
        }
    }

    // MARK: - Emit error de escaneo

    /// Emite un evento `scan_error` cuando el escáner falla antes del parser.
    func sendScanError(_ message: String) async {
        guard let ch = channel, connectionState == .connected else { return }

        let payload = ScanErrorPayload(
            error: message,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await ch.broadcast(event: "scan_error", message: payload)
            #if DEBUG
            print("[WebSocketManager] ✓ 'scan_error' enviado")
            #endif
        } catch {
            #if DEBUG
            print("[WebSocketManager] ✗ broadcast scan_error falló: \(error)")
            #endif
        }
    }
}

// MARK: - VerificationPayload

/// Payload Codable para el evento `dni_verified`.
///
/// Usar un tipo Codable concreto en lugar de [String: AnyJSON] garantiza:
///   • Resolución del overload `broadcast(event:message: some Codable) async throws`
///   • Serialización JSON predecible con snake_case explícito
///   • Campos nil omitidos automáticamente por JSONEncoder
private struct VerificationPayload: Codable {

    let isValid: Bool
    let qrType: String?
    let scanMethod: String
    let timestamp: String
    let documentNumber: String?
    let fullName: String?
    let dateOfBirth: String?
    let gender: String?
    let documentExpiry: String?
    let isAdult: Bool?
    let secondsUntilExpiry: Int?
    let errorCode: String?
    let errorMessage: String?

    // Campos extendidos (QR completo tipo 8)
    let nationality: String?
    let address: String?
    let birthPlace: String?
    let parentsNames: String?
    let supportNumber: String?

    // Campos exclusivos NFC
    let issueDate: String?
    let documentTypeCode: String?

    // Imágenes en base64
    let thumbnailData: String?
    let signatureData: String?

    enum CodingKeys: String, CodingKey {
        case isValid            = "is_valid"
        case qrType             = "qr_type"
        case scanMethod         = "scan_method"
        case timestamp
        case documentNumber     = "document_number"
        case fullName           = "full_name"
        case dateOfBirth        = "date_of_birth"
        case gender
        case documentExpiry     = "document_expiry"
        case isAdult            = "is_adult"
        case secondsUntilExpiry = "seconds_until_expiry"
        case errorCode          = "error_code"
        case errorMessage       = "error_message"
        case nationality
        case address
        case birthPlace         = "birth_place"
        case parentsNames       = "parents_names"
        case supportNumber      = "support_number"
        case issueDate          = "issue_date"
        case documentTypeCode   = "document_type_code"
        case thumbnailData      = "thumbnail_data"
        case signatureData      = "signature_data"
    }

    init(from result: MiDNIVerificationResult) {
        self.isValid            = result.isValid
        self.qrType             = result.qrType?.stringValue
        self.scanMethod         = result.scanMethod
        self.timestamp          = ISO8601DateFormatter().string(from: result.verificationTimestamp)
        self.documentNumber     = result.documentNumber
        self.fullName           = result.fullName
        self.dateOfBirth        = result.dateOfBirth
        self.gender             = result.gender
        self.documentExpiry     = result.documentExpiry
        self.isAdult            = result.isAdult
        self.secondsUntilExpiry = result.secondsUntilExpiry
        self.errorCode          = result.errorType?.errorCode
        self.errorMessage       = result.errorType?.errorDescription
            ?? result.errorType?.errorCode

        // Campos extendidos
        self.nationality        = result.nationality
        self.address            = result.address
        self.birthPlace         = result.birthPlace
        self.parentsNames       = result.parentsNames
        self.supportNumber      = result.supportNumber

        // NFC
        self.issueDate          = result.issueDate
        self.documentTypeCode   = result.documentTypeCode

        // Imágenes → JPEG → base64
        // El QR contiene JPEG2000 (tag 0x50) que los navegadores no soportan.
        // NFC ya entrega JPEG normal (via jpegData en NFCViewModel).
        // UIImage soporta ambos formatos; al re-exportar con jpegData()
        // garantizamos JPEG estándar compatible con <img> en el dashboard.
        self.thumbnailData = result.thumbnailImageData.flatMap { data in
            UIImage(data: data)?.jpegData(compressionQuality: 0.85)?.base64EncodedString()
        }
        self.signatureData = result.signatureImageData.flatMap { data in
            UIImage(data: data)?.jpegData(compressionQuality: 0.85)?.base64EncodedString()
        }
    }
}

// MARK: - ScanErrorPayload

private struct ScanErrorPayload: Codable {
    let error: String
    let timestamp: String
}

// MARK: - DBVerificationRow

/// Fila que se inserta en la tabla `verifications` de Supabase.
///
/// Esquema completo esperado en Supabase — ejecutar supabase_migration.sql
/// para añadir los campos extendidos si aún no existen.
private struct DBVerificationRow: Encodable {

    let accountId: String
    let isValid: Bool
    let qrType: String?
    let scanMethod: String
    let documentNumber: String?
    let fullName: String?
    let dateOfBirth: String?
    let gender: String?
    let documentExpiry: String?
    let isAdult: Bool?
    let errorCode: String?
    let errorMessage: String?

    // Campos extendidos (QR completo tipo 8)
    let nationality: String?
    let address: String?
    let birthPlace: String?
    let parentsNames: String?
    let supportNumber: String?

    // Campos exclusivos NFC
    let issueDate: String?
    let documentTypeCode: String?

    // Imágenes en base64
    let thumbnailData: String?
    let signatureData: String?

    enum CodingKeys: String, CodingKey {
        case accountId      = "account_id"
        case isValid        = "is_valid"
        case qrType         = "qr_type"
        case scanMethod     = "scan_method"
        case documentNumber = "document_number"
        case fullName       = "full_name"
        case dateOfBirth    = "date_of_birth"
        case gender
        case documentExpiry = "document_expiry"
        case isAdult        = "is_adult"
        case errorCode      = "error_code"
        case errorMessage   = "error_message"
        case nationality
        case address
        case birthPlace     = "birth_place"
        case parentsNames   = "parents_names"
        case supportNumber  = "support_number"
        case issueDate      = "issue_date"
        case documentTypeCode = "document_type_code"
        case thumbnailData  = "thumbnail_data"
        case signatureData  = "signature_data"
    }

    init(accountId: String, payload: VerificationPayload) {
        self.accountId      = accountId
        self.isValid        = payload.isValid
        self.qrType         = payload.qrType
        self.scanMethod     = payload.scanMethod
        self.documentNumber = payload.documentNumber
        self.fullName       = payload.fullName
        self.dateOfBirth    = payload.dateOfBirth
        self.gender         = payload.gender
        self.documentExpiry = payload.documentExpiry
        self.isAdult        = payload.isAdult
        self.errorCode      = payload.errorCode
        self.errorMessage   = payload.errorMessage
        self.nationality    = payload.nationality
        self.address        = payload.address
        self.birthPlace     = payload.birthPlace
        self.parentsNames   = payload.parentsNames
        self.supportNumber  = payload.supportNumber
        self.issueDate      = payload.issueDate
        self.documentTypeCode = payload.documentTypeCode
        self.thumbnailData  = payload.thumbnailData
        self.signatureData  = payload.signatureData
    }
}
