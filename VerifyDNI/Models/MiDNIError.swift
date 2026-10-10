// MiDNIError.swift
// VerifyDNI
//
// Enumeración centralizada de errores del sistema MiDNI.
// Compartida por CertificateManager, ECDSAVerifier y MiDNIParser.

import Foundation

// MARK: - MiDNIError

/// Errores posibles durante el proceso de verificación de un QR MiDNI.
///
/// Usar `errorDescription` (protocolo `LocalizedError`) para mostrar
/// mensajes al usuario en la UI.
enum MiDNIError: Error, LocalizedError, Equatable {

    // ── Errores de cabecera ──────────────────────────────────────────────────

    /// El primer byte del QR no es 0xDC.
    /// El código escaneado no es un documento MiDNI.
    case invalidMagicConstant

    /// El byte de versión no es 0x03.
    /// La app necesita actualizarse para leer este formato.
    case unsupportedVersion

    /// La cabecera del QR está truncada o contiene datos inválidos.
    case malformedHeader

    // ── Errores de certificado ───────────────────────────────────────────────

    /// El certificado X.509 de la Policía Nacional no pudo descargarse,
    /// parsearse o no supera la validación (subject, fechas).
    case invalidCertificate

    /// El número de serie del certificado en Keychain no coincide con
    /// la referencia incluida en la cabecera del QR.
    case certificateSerialMismatch

    // ── Errores de firma ─────────────────────────────────────────────────────

    /// La firma ECDSA no es válida sobre los datos presentados.
    /// Posible falsificación o alteración del QR.
    case invalidSignature

    // ── Errores de caducidad ─────────────────────────────────────────────────

    /// El QR ha superado su tiempo de validez (tag 0x80).
    /// - Parameter secondsAgo: Segundos transcurridos desde la caducidad.
    case expiredQR(secondsAgo: Int)

    // ── Errores de datos ─────────────────────────────────────────────────────

    /// Un TLV está malformado: tag inesperado, longitud incorrecta
    /// o valor truncado.
    case malformedTLV

    // ── Errores de red ───────────────────────────────────────────────────────

    /// No hay conexión a internet y el certificado no está en Keychain.
    case noInternetConnection

    // ── Error genérico ───────────────────────────────────────────────────────

    /// Error no clasificado. `message` contiene detalles para diagnóstico.
    case unknownError(String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .invalidMagicConstant:
            return "El QR no es un documento MiDNI válido"

        case .unsupportedVersion:
            return "Versión de QR no soportada — actualiza la app"

        case .malformedHeader:
            return "Cabecera del QR malformada"

        case .invalidCertificate:
            return "El certificado de la Policía Nacional no es válido"

        case .certificateSerialMismatch:
            return "Certificado de firma no encontrado — el QR puede haberse generado con una versión antigua de MiDNI"

        case .invalidSignature:
            return "La firma del QR no es válida — posible falsificación"

        case .expiredQR(let seconds):
            if seconds < 60 {
                return "QR caducado hace \(seconds) segundo\(seconds == 1 ? "" : "s")"
            } else {
                let minutes = seconds / 60
                return "QR caducado hace \(minutes) minuto\(minutes == 1 ? "" : "s")"
            }

        case .malformedTLV:
            return "Los datos del QR están malformados"

        case .noInternetConnection:
            return "Sin conexión a internet — no se puede verificar el certificado"

        case .unknownError(let msg):
            return "Error inesperado: \(msg)"
        }
    }

    /// Instrucción breve de qué debe hacer el usuario ante este error.
    var userInstruction: String {
        switch self {
        case .invalidMagicConstant, .malformedHeader, .malformedTLV:
            return "Pide al cliente que genere un QR nuevo desde la app MiDNI"

        case .unsupportedVersion:
            return "Actualiza VerifyDNI desde la App Store"

        case .invalidCertificate:
            return "Comprueba tu conexión a internet y reinicia la app"

        case .certificateSerialMismatch:
            return "Pide al cliente que actualice la app MiDNI y genere un QR nuevo"

        case .invalidSignature:
            return "No aceptes este documento — el QR podría ser falso"

        case .expiredQR:
            return "El QR caduca en 2 minutos. Pide al cliente uno nuevo"

        case .noInternetConnection:
            return "Conecta el dispositivo a internet y vuelve a intentarlo"

        case .unknownError:
            return "Inténtalo de nuevo. Si persiste, reinicia la app"
        }
    }

    /// Código corto de error para serialización en Supabase / WebSocket.
    var errorCode: String {
        switch self {
        case .invalidMagicConstant:      return "INVALID_MAGIC"
        case .unsupportedVersion:        return "UNSUPPORTED_VERSION"
        case .malformedHeader:           return "MALFORMED_HEADER"
        case .invalidCertificate:        return "INVALID_CERT"
        case .certificateSerialMismatch: return "CERT_SERIAL_MISMATCH"
        case .invalidSignature:          return "INVALID_SIGNATURE"
        case .expiredQR:                 return "EXPIRED_QR"
        case .malformedTLV:              return "MALFORMED_TLV"
        case .noInternetConnection:      return "NO_INTERNET"
        case .unknownError:              return "UNKNOWN_ERROR"
        }
    }

    // MARK: - Equatable (sin asociados complejos)

    static func == (lhs: MiDNIError, rhs: MiDNIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidMagicConstant, .invalidMagicConstant),
             (.unsupportedVersion, .unsupportedVersion),
             (.malformedHeader, .malformedHeader),
             (.invalidCertificate, .invalidCertificate),
             (.certificateSerialMismatch, .certificateSerialMismatch),
             (.invalidSignature, .invalidSignature),
             (.malformedTLV, .malformedTLV),
             (.noInternetConnection, .noInternetConnection):
            return true
        case (.expiredQR(let a), .expiredQR(let b)):
            return a == b
        case (.unknownError(let a), .unknownError(let b)):
            return a == b
        default:
            return false
        }
    }
}
