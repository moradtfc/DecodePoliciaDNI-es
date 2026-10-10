// MiDNIVerificationResult.swift
// VerifyDNI
//
// Modelos de datos del resultado de verificación de un QR MiDNI.
// Todos los tipos de esta sección son value types (struct/enum)
// sin dependencias externas.

import Foundation

// MARK: - QRType

/// Tipo de QR MiDNI según el byte de tipo en la cabecera.
///
/// - `simple`   (7): Verificación básica — datos esenciales del documento.
/// - `complete` (8): Verificación completa — incluye lugar de nacimiento,
///                   nacionalidad, padres, etc.
/// - `age`      (9): Verificación de mayoría de edad — mínima información.
enum QRType: Int, CustomStringConvertible {
    case simple   = 7
    case complete = 8
    case age      = 9

    var description: String {
        switch self {
        case .simple:   return "Verificación simple"
        case .complete: return "Verificación completa"
        case .age:      return "Verificación de edad"
        }
    }

    /// Identificador corto para el evento WebSocket.
    var eventKey: String {
        switch self {
        case .simple:   return "simple"
        case .complete: return "complete"
        case .age:      return "age"
        }
    }

    /// Valor de cadena para serialización JSON / Supabase.
    var stringValue: String { eventKey }
}

// MARK: - String + nilIfEmpty

extension String {
    /// Devuelve `nil` si la cadena (tras eliminar espacios) está vacía; si no, devuelve `self`.
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - MiDNIVerificationResult

/// Resultado completo de verificar un QR MiDNI.
///
/// Si `isValid == true`, los campos de datos del ciudadano están
/// disponibles según el `qrType` del QR.
///
/// Si `isValid == false`, `errorType` indica el motivo del fallo
/// y la mayoría de los campos de datos serán `nil`.
///
/// ### Ciclo de vida de los datos
/// Este struct nunca se persiste en disco. Se crea en `MiDNIParser`,
/// se muestra en `ResultView` y se descarta cuando el usuario vuelve
/// a `HomeView`. No almacenar en UserDefaults, CoreData ni ficheros.
struct MiDNIVerificationResult {

    // ── Resultado de la verificación ─────────────────────────────────────────

    /// `true` si el QR es auténtico, está firmado correctamente y no ha caducado.
    let isValid: Bool

    /// Motivo del fallo cuando `isValid == false`. `nil` si `isValid == true`.
    let errorType: MiDNIError?

    /// Tipo de QR escaneado (simple, completo o edad).
    /// `nil` cuando el escaneo fue por NFC (no aplica).
    let qrType: QRType?

    /// Método de escaneo: "qr" o "nfc".
    let scanMethod: String

    // ── Datos del documento — presentes en todos los tipos de QR ─────────────

    /// Número de DNI (tag 0x40). Ejemplo: `"12345678Z"`.
    let documentNumber: String?

    /// Fecha de nacimiento en formato `"DD-MM-YYYY"` (tag 0x42).
    let dateOfBirth: String?

    /// Nombre(s) de pila (tag 0x44). Ejemplo: `"CARMEN"`.
    let name: String?

    /// Primer y segundo apellido (tag 0x46). Ejemplo: `"ESPAÑOLA ESPAÑOLA"`.
    let surnames: String?

    /// Sexo (tag 0x48): `"M"` (masculino) o `"F"` (femenino).
    let gender: String?

    /// Fecha de caducidad del documento en formato `"DD-MM-YYYY"` (tag 0x4C).
    let documentExpiry: String?

    // ── Imagen ────────────────────────────────────────────────────────────────

    /// Miniatura del ciudadano en formato JPEG2000 (tag 0x50).
    /// Decodificar con `UIImage(data:)` en iOS — el sistema soporta JP2 nativamente.
    let thumbnailImageData: Data?

    // ── Datos adicionales — presentes en QR tipo 8 (completo) ────────────────

    /// Dirección completa (tag 0x60).
    let address: String?

    /// Lugar de nacimiento, línea 1 (tag 0x62).
    let birthPlaceLine1: String?

    /// Lugar de nacimiento, línea 2 (tag 0x78).
    let birthPlaceLine2: String?

    /// Lugar de nacimiento, línea 3 (tag 0x7A).
    let birthPlaceLine3: String?

    /// Código de nacionalidad (tag 0x64). Ejemplo: `"ESP"`.
    let nationality: String?

    /// Nombre del padre y la madre (tag 0x66).
    let parentsNames: String?

    /// Número de soporte del DNI físico (tag 0x68).
    let supportNumber: String?

    // ── Mayoría de edad — presente en tipos 8 y 9 ────────────────────────────

    /// `true` si el ciudadano es mayor de edad (tag 0x70: `0x01 = true`, `0x00 = false`).
    /// Si el tag 0x70 no existe pero hay fecha de nacimiento (tag 0x42),
    /// se calcula automáticamente en `MiDNIParser`.
    let isAdult: Bool?

    // ── Campos adicionales solo disponibles por lectura NFC del chip ──────────

    /// Fecha de expedición del documento en formato `"DD-MM-YYYY"`.
    /// Extraída del SOD (Security Object Document) del chip NFC.
    /// `nil` si se obtiene por QR (el QR no contiene fecha de expedición).
    let issueDate: String?

    /// Datos JPEG de la firma manuscrita del titular (DG7 del chip NFC).
    /// `nil` si se obtiene por QR o si el chip no tiene DG7.
    let signatureImageData: Data?

    /// Código de tipo de documento del chip NFC: `"I"` = DNI / TIE, `"P"` = Pasaporte.
    /// Se usa para calcular `documentTypeLabel`. `nil` si se obtiene por QR.
    let documentTypeCode: String?

    // ── Caducidad del QR ──────────────────────────────────────────────────────

    /// Fecha y hora de caducidad de los datos del QR en UTC (tag 0x80).
    /// Formato original en el QR: `"DD-MM-YYYY hh:mm:ss"`.
    let dataExpiryDateTime: Date?

    // ── Metadatos de la verificación ──────────────────────────────────────────

    /// Momento exacto en que se realizó la verificación.
    let verificationTimestamp: Date

    /// Segundos transcurridos desde la creación del QR hasta la verificación.
    /// `nil` si no se puede calcular con precisión (MiDNI no incluye fecha de creación).
    let qrAgeSeconds: Int?

    // MARK: - Helpers computados

    /// Etiqueta legible del tipo de documento: "DNI", "TIE" o "Pasaporte".
    ///
    /// - `"I"`  → `"DNI"` (identity card española)
    /// - `"IR"` → `"TIE"` (Tarjeta de Identidad de Extranjero / residence permit)
    /// - `"P"`  → `"Pasaporte"`
    /// - `nil`  → `"DNI"` (valor por defecto, e.g. QR legacy)
    var documentTypeLabel: String {
        switch documentTypeCode?.uppercased() {
        case "I":
            return "DNI"
        case "IR":
            return "TIE"
        case "P":
            return "Pasaporte"
        default:
            return "DNI"
        }
    }

    /// `true` si el documento es un TIE (Tarjeta de Identificación de Extranjero).
    var isTIE: Bool { documentTypeLabel == "TIE" }

    /// `true` si la fecha de caducidad del documento ya ha pasado.
    /// Los DNI permanentes ("01-01-9999") nunca se consideran caducados.
    var isDocumentExpired: Bool {
        guard let expiry = documentExpiry else { return false }
        let fmt = DateFormatter()
        fmt.dateFormat = "dd-MM-yyyy"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        guard let date = fmt.date(from: expiry) else { return false }
        // Año ≥ 9000 = DNI permanente → nunca caducado
        if Calendar.current.component(.year, from: date) >= 9000 { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }

    /// Nombre completo en formato "NOMBRE APELLIDO1 APELLIDO2".
    var fullName: String? {
        let parts = [name, surnames].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Segundos restantes de validez del QR desde **ahora**.
    /// Devuelve `nil` si el QR ya ha caducado o no tiene fecha de caducidad.
    var secondsUntilExpiry: Int? {
        guard let expiry = dataExpiryDateTime else { return nil }
        let remaining = Int(expiry.timeIntervalSince(Date()))
        return remaining > 0 ? remaining : nil
    }

    /// Lugar de nacimiento formateado en una sola cadena (líneas 1, 2 y 3 separadas por coma).
    var birthPlace: String? {
        let lines = [birthPlaceLine1, birthPlaceLine2, birthPlaceLine3]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? nil : lines.joined(separator: ", ")
    }

    /// Resultado para el caso de error — constructor conveniente.
    static func failure(
        _ error: MiDNIError,
        qrType: QRType? = .simple,
        scanMethod: String = "qr"
    ) -> MiDNIVerificationResult {
        MiDNIVerificationResult(
            isValid:              false,
            errorType:            error,
            qrType:               qrType,
            scanMethod:           scanMethod,
            documentNumber:       nil,
            dateOfBirth:          nil,
            name:                 nil,
            surnames:             nil,
            gender:               nil,
            documentExpiry:       nil,
            thumbnailImageData:   nil,
            address:              nil,
            birthPlaceLine1:      nil,
            birthPlaceLine2:      nil,
            birthPlaceLine3:      nil,
            nationality:          nil,
            parentsNames:         nil,
            supportNumber:        nil,
            isAdult:              nil,
            issueDate:            nil,
            signatureImageData:   nil,
            documentTypeCode:     nil,
            dataExpiryDateTime:   nil,
            verificationTimestamp: Date(),
            qrAgeSeconds:         nil
        )
    }
}

// MARK: - VerificationLog

/// Entrada del historial de verificaciones del día.
///
/// Se guarda exclusivamente en memoria (no se persiste en disco).
/// La lista se vacía automáticamente al cambiar de día o al cerrar la app.
struct VerificationLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let isValid: Bool
    let documentNumber: String?
    let fullName: String?
    let errorType: MiDNIError?
    let qrType: QRType?

    /// Inicializar desde un `MiDNIVerificationResult`.
    init(from result: MiDNIVerificationResult) {
        self.timestamp      = result.verificationTimestamp
        self.isValid        = result.isValid
        self.documentNumber = result.documentNumber
        self.fullName       = result.fullName
        self.errorType      = result.errorType
        self.qrType         = result.qrType
    }

    /// Hora formateada para mostrar en el historial (HH:mm:ss).
    var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        fmt.locale = Locale(identifier: "es_ES")
        return fmt.string(from: timestamp)
    }
}
