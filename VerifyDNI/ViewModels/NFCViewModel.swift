// NFCViewModel.swift
// VerifyDNI
// ViewModel que gestiona la lectura del chip NFC del DNI físico español.
// Flujo: cámara escanea MRZ → se calcula MRZ key → NFC lee el chip.

import SwiftUI
import Combine
import CoreNFC
import NFCPassportReader

@MainActor
final class NFCViewModel: ObservableObject {

    // MARK: - Estado

    @Published var isReading:    Bool          = false
    @Published var nfcError:     NFCReadError? = nil

    /// Progreso de lectura del chip NFC (0.0 – 1.0).
    @Published var nfcProgress:    Double = 0.0
    /// Fase textual actual del proceso NFC para mostrar en la UI.
    @Published var nfcPhaseLabel:  String = "Buscando chip..."
    /// `true` desde que la sesión NFC arranca (requestPresentPassport) hasta que termina.
    /// La vista lo observa para cambiar de fase solo cuando el hardware está listo,
    /// evitando mostrar la pantalla azul si el NFC falla antes de iniciarse.
    @Published var nfcSessionStarted: Bool = false

    // Datos obtenidos del escáner MRZ (publicados para mostrar en UI de confirmación)
    private var mrzKey:              String = ""
    @Published var scannedDocNum:    String = ""
    @Published var scannedDOB:       String = ""   // yyMMdd
    @Published var scannedExpiry:    String = ""   // yyMMdd
    @Published var scannedName:      String = ""
    /// Nacionalidad detectada en el MRZ (antes del NFC). "ESP"=DNI, otro=TIE.
    @Published var scannedNationality: String? = nil

    // Tiempo de inicio de sesión NFC (para diferenciar fallo de entitlement vs timeout físico)
    private var nfcStartTime: Date?

    // MARK: - NFCReadError

    enum NFCReadError {
        case chipNotFound
        case invalidMRZ
        case readCancelled
        case unsupportedDevice
        case tagLost
        case timeout
        case permissionError   // Entitlement / provisioning issue
        case unknown(String)

        var title: String {
            switch self {
            case .chipNotFound:      return "Chip no detectado"
            case .invalidMRZ:        return "MRZ incorrecto"
            case .readCancelled:     return "Lectura cancelada"
            case .unsupportedDevice: return "NFC no disponible"
            case .tagLost:           return "Conexión perdida"
            case .timeout:           return "Tiempo agotado"
            case .permissionError:   return "Permiso NFC denegado"
            case .unknown:           return "Error de lectura"
            }
        }

        var message: String {
            switch self {
            case .chipNotFound:
                return "No se detectó el chip NFC. Desliza el DNI lentamente por toda la parte trasera del iPhone."
            case .invalidMRZ:
                return "La clave MRZ es incorrecta. Vuelve a escanear el DNI asegurándote de que las dos líneas de código son legibles."
            case .readCancelled:
                return "La lectura fue cancelada."
            case .unsupportedDevice:
                return "Este dispositivo no soporta NFC (mínimo iPhone 7 con iOS 13)."
            case .tagLost:
                return "La conexión con el chip se interrumpió. Espera 5 segundos para que el NFC se reinicie y vuelve a intentarlo."
            case .timeout:
                return "No se detectó el chip en 60 segundos. Desliza el DNI MUY lentamente por la parte trasera del iPhone, de arriba hacia abajo."
            case .permissionError:
                return "El perfil de aprovisionamiento no incluye NFC Tag Reading. Verifica Signing & Capabilities en Xcode."
            case .unknown(let detail):
                return detail.isEmpty ? "Error inesperado. Inténtalo de nuevo." : detail
            }
        }

        var instruction: String {
            switch self {
            case .chipNotFound, .timeout:
                return "Desliza el DNI de arriba a abajo por toda la parte trasera del iPhone"
            case .tagLost:
                return "Espera ~5 segundos antes de reintentar para que el hardware NFC se recupere"
            case .invalidMRZ:
                return "Vuelve a escanear el MRZ con buena iluminación"
            case .readCancelled:
                return "Pulsa Reintentar cuando estés listo"
            case .unsupportedDevice:
                return "Se requiere iPhone 7 o posterior con iOS 13+"
            case .permissionError:
                return "Revisa el perfil de aprovisionamiento en Xcode"
            case .unknown:
                return "Inténtalo de nuevo o usa el escáner QR"
            }
        }

        var canRetry: Bool {
            if case .unsupportedDevice = self { return false }
            if case .permissionError   = self { return false }
            return true
        }
    }

    // MARK: - Reader

    private let passportReader = PassportReader()

    // MARK: - Procesar resultado MRZ

    /// Recibe el resultado del escáner MRZ y calcula la MRZ key.
    func processMRZResult(_ scanResult: MRZScanResult) {
        let docNumber = scanResult.documentNumber.uppercased()

        // Usar las cadenas yyMMdd del propio scanner (más fiables que convertir Date→String)
        let birthDate  = scanResult.dobString.isEmpty
            ? dateToMRZString(scanResult.dateOfBirth)
            : scanResult.dobString
        let expiryDate = scanResult.expiryString.isEmpty
            ? dateToMRZString(scanResult.expiryDate)
            : scanResult.expiryString

        scannedDocNum     = docNumber
        scannedDOB        = birthDate
        scannedExpiry     = expiryDate
        scannedName       = "\(scanResult.givenNames) \(scanResult.surnames)"
            .trimmingCharacters(in: CharacterSet.whitespaces)
        scannedNationality = scanResult.nationality

        mrzKey = computeMRZKey(
            documentNumber: docNumber,
            dateOfBirth:    birthDate,
            expiryDate:     expiryDate
        )

        // NSLog con interpolación directa (las variantes con formato %@ no están disponibles en Swift)
        let docType = (scanResult.nationality.flatMap { $0 == "ESP" ? "DNI" : "TIE(\($0))" }) ?? "?"
        NSLog("[VerifyDNI] ✅ MRZ procesado — doc: \(docNumber), dob: \(birthDate), exp: \(expiryDate), tipo: \(docType)")
        NSLog("[VerifyDNI] ✅ MRZ key calculada (\(mrzKey.count) chars): \(mrzKey)")
    }

    // MARK: - Lectura NFC

    func startNFCReading(
        onSuccess: @escaping (MiDNIVerificationResult) -> Void,
        onError:   @escaping (NFCReadError) -> Void
    ) async {
        NSLog("[VerifyDNI] 🔵 startNFCReading — mrzKey.count=\(mrzKey.count)")

        guard NFCTagReaderSession.readingAvailable else {
            NSLog("[VerifyDNI] 🔴 NFCTagReaderSession.readingAvailable = FALSE")
            let err = NFCReadError.unsupportedDevice
            nfcError = err
            onError(err)
            return
        }

        guard !mrzKey.isEmpty else {
            NSLog("[VerifyDNI] 🔴 mrzKey vacía — escanea el MRZ primero")
            return
        }

        nfcError          = nil
        isReading         = true
        nfcProgress       = 0.0
        nfcPhaseLabel     = "Buscando chip..."
        nfcSessionStarted = false
        nfcStartTime      = Date()

        let customMessages: (NFCViewDisplayMessage) -> String? = { [weak self] msg in
            switch msg {
            case .requestPresentPassport:
                NSLog("[VerifyDNI] 🟡 NFC → requestPresentPassport")
                DispatchQueue.main.async {
                    self?.nfcSessionStarted = true   // la sesión arrancó: la vista puede cambiar de fase
                    self?.nfcPhaseLabel     = "Buscando chip..."
                    self?.nfcProgress       = 0.0
                }
                return "Desliza el DNI por la parte trasera del iPhone"
            case .authenticatingWithPassport:
                NSLog("[VerifyDNI] 🟡 NFC → authenticatingWithPassport ✓ CHIP DETECTADO")
                DispatchQueue.main.async {
                    self?.nfcPhaseLabel = "Chip detectado — autenticando..."
                    self?.nfcProgress   = 0.05
                }
                return "Chip detectado — autenticando..."
            case .readingDataGroupProgress(_, let progress):
                NSLog("[VerifyDNI] 🟡 NFC → readingDataGroup \(progress)%%")
                DispatchQueue.main.async {
                    self?.nfcPhaseLabel = "Leyendo datos del chip..."
                    self?.nfcProgress = 0.10 + (Double(progress) / 100.0) * 0.85
                }
                return "Leyendo datos del chip..."
            case .successfulRead:
                NSLog("[VerifyDNI] 🟢 NFC → successfulRead")
                DispatchQueue.main.async {
                    self?.nfcPhaseLabel = "Lectura completada"
                    self?.nfcProgress   = 1.0
                }
                return "Lectura completada ✓"
            default:
                return nil
            }
        }

        // Solo los grupos que realmente usamos:
        //  DG1  → MRZ (nombre, DOB, caducidad, nº documento, nacionalidad)
        //  DG2  → Foto del titular (JPEG2000)
        //  DG7  → Firma manuscrita (solo DNI)
        //  DG11 → Lugar de nacimiento y dirección (estándar ICAO — fallback si DG13 no tiene)
        //  DG13 → Datos extendidos españoles (apellidos, padres, lugar nac., dirección)
        //  SOD  → Security Object Document (para fecha de expedición)
        let tagsToRead: [DataGroupId] = [.COM, .DG1, .DG2, .DG7, .DG11, .DG13, .SOD]
        NSLog("[VerifyDNI] 🔵 readPassport — grupos: \(tagsToRead.map { $0.getName() })")

        do {
            let passport = try await passportReader.readPassport(
                mrzKey:               mrzKey,
                tags:                 tagsToRead,
                customDisplayMessage: customMessages
            )

            let elapsed = Date().timeIntervalSince(nfcStartTime ?? Date())
            isReading         = false
            nfcSessionStarted = false
            NSLog("[VerifyDNI] 🟢 Lectura NFC OK en \(String(format: "%.1f", elapsed))s — doc: \(passport.documentNumber)")

            logPassportDiagnostics(passport)

            let result = convertToVerificationResult(passport)
            // NO enviar aquí — el envío lo controla el botón
            // "Enviar datos al panel" en ResultView para evitar
            // doble registro en la tabla verifications.
            onSuccess(result)

        } catch {
            let elapsed = Date().timeIntervalSince(nfcStartTime ?? Date())
            isReading         = false
            nfcSessionStarted = false

            NSLog("[VerifyDNI] 🔴 Error NFC tras \(String(format: "%.1f", elapsed))s")
            NSLog("[VerifyDNI] 🔴 Error type: \(type(of: error))")
            NSLog("[VerifyDNI] 🔴 Error desc: \(error.localizedDescription)")

            let mapped = mapError(error, elapsed: elapsed)
            nfcError = mapped
            onError(mapped)
        }
    }

    // MARK: - MRZ Key computation

    private func computeMRZKey(documentNumber: String,
                                dateOfBirth: String,
                                expiryDate: String) -> String {
        // Número de documento padded a 9 chars con '<' (requisito ICAO 9303)
        let paddedDoc = documentNumber.padding(toLength: 9, withPad: "<", startingAt: 0)
        let docCheck  = calcCheckSum(paddedDoc)
        let dobCheck  = calcCheckSum(dateOfBirth)
        let expCheck  = calcCheckSum(expiryDate)
        return "\(paddedDoc)\(docCheck)\(dateOfBirth)\(dobCheck)\(expiryDate)\(expCheck)"
    }

    private func calcCheckSum(_ input: String) -> Int {
        let map: [Character: Int] = {
            var m = [Character: Int]()
            for c: Character in ["0","1","2","3","4","5","6","7","8","9"] {
                m[c] = Int(String(c))!
            }
            m["<"] = 0; m[" "] = 0
            let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            for (i, c) in letters.enumerated() { m[c] = i + 10 }
            return m
        }()
        let weights = [7, 3, 1]
        var sum = 0
        for (i, c) in input.enumerated() {
            sum += (map[c] ?? 0) * weights[i % 3]
        }
        return sum % 10
    }

    private func dateToMRZString(_ date: Date?) -> String {
        guard let date else { return "000000" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyMMdd"
        fmt.locale     = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: date)
    }

    // MARK: - Conversión NFCPassportModel → MiDNIVerificationResult

    private func convertToVerificationResult(_ passport: NFCPassportModel) -> MiDNIVerificationResult {

        // ── Tipo de documento ────────────────────────────────────────────────
        // El chip NFC devuelve "I" para todas las identity cards (TD1).
        // Diferenciamos DNI de TIE por nacionalidad:
        //   "I" + ESP → DNI → guardamos "I"
        //   "I" + otra → TIE → guardamos "IR" (ICAO residence permit)
        //   "P"        → Pasaporte → guardamos "P"
        let rawDocType = passport.documentType.nilIfEmpty
        let nationality = passport.nationality.nilIfEmpty
        let docTypeCode: String? = {
            guard let raw = rawDocType else { return nil }
            if raw.hasPrefix("P") { return "P" }
            // Identity card (TD1): distinguir DNI de TIE
            if nationality?.uppercased() == "ESP" {
                return "I"   // DNI español
            } else {
                return "IR"  // TIE (Tarjeta de Identidad de Extranjero)
            }
        }()

        // ── Número de documento ──────────────────────────────────────────────
        // personalNumber = número real del DNI/NIE (ej. "12345678Z"), viene del tag "53" del MRZ.
        //   IMPORTANTE: cuando el tag "53" no existe, el modelo devuelve "?" (no nil ni ""),
        //   por lo que usamos cleanPassportField() que filtra ese placeholder.
        // documentNumber = número de soporte ICAO (ej. "IDESP123456789"), viene del campo "5A".
        //   Para TIE, documentNumber ES el NIE (número del documento visible en la tarjeta).
        let dniNumber     = cleanPassportField(passport.personalNumber)
                            ?? passport.documentNumber.nilIfEmpty
        let soporteNumber = passport.documentNumber.nilIfEmpty

        // ── Nombres y apellidos ──────────────────────────────────────────────
        // Preferimos DG13 (con tildes y ñ) sobre DG1/MRZ (sin tildes).
        // dg13Names / dg13LastNames son nuestras extensiones sobre NFCPassportModel.
        let givenNames: String? = passport.dg13Names?.nilIfEmpty
            ?? passport.firstName.nilIfEmpty

        let surnames: String? = passport.dg13LastNames?.nilIfEmpty
            .map { $0.replacingOccurrences(of: "/", with: " ")
                     .trimmingCharacters(in: CharacterSet.whitespaces) }
            ?? passport.lastName.nilIfEmpty

        // ── Padres ───────────────────────────────────────────────────────────
        // DG13 formato "PADRE/MADRE" → mostrar como "PADRE / MADRE"
        let parents: String? = {
            guard let raw = passport.dg13Parents?.nilIfEmpty else { return nil }
            let parts = raw.components(separatedBy: "/")
            guard parts.count >= 2 else { return raw }
            let padre = parts[0].trimmingCharacters(in: CharacterSet.whitespaces)
            let madre = parts[1].trimmingCharacters(in: CharacterSet.whitespaces)
            return "\(padre) / \(madre)"
        }()

        // ── Lugar de nacimiento ──────────────────────────────────────────────
        // Prioridad: DG13 índices 11 (municipio) y 12 (provincia) — confirmados
        //            en chips reales de DNI español.
        // Fallback:  DG11 passport.placeOfBirth — puede venir como
        //            "CIUDAD" o "CIUDAD<PROVINCIA" según versión del chip.
        var birthCity: String?     = passport.dg13BirthCity
        var birthProvince: String? = passport.dg13BirthProvince

        if birthCity == nil, let rawPlace = passport.placeOfBirth?.nilIfEmpty {
            let parts = rawPlace.components(separatedBy: "<")
            birthCity     = parts.first?.trimmingCharacters(in: .whitespaces).nilIfEmpty
            birthProvince = parts.count > 1
                ? parts[1].trimmingCharacters(in: .whitespaces).nilIfEmpty
                : nil
        }

        // ── Dirección de residencia ──────────────────────────────────────────
        // Solo se toma de DG11 (estándar ICAO) — formato "CALLE<MUNICIPIO<PROVINCIA".
        // Los índices [14-16] de DG13 contienen la dirección actual y no se usan
        // aquí para evitar confundirla con el lugar de nacimiento.
        var residenceDisplay: String? = nil
        if let rawAddr = passport.residenceAddress?.nilIfEmpty {
            residenceDisplay = rawAddr
                .replacingOccurrences(of: "<", with: " ")
                .trimmingCharacters(in: .whitespaces)
                .nilIfEmpty
        }

        // ── Imágenes ─────────────────────────────────────────────────────────
        let photo     = passport.passportImage?.jpegData(compressionQuality: 0.85)
        let signature = passport.signatureImage?.jpegData(compressionQuality: 0.85)

        // ── Fecha de expedición ──────────────────────────────────────────────
        // computedIssueDate calcula la fecha restando la vigencia (2/5/10 años según edad)
        // a la fecha de caducidad — misma lógica que Santander en calculateIssueDateByRules().
        // La fecha de expedición también es siglo 21 (ningún DNI fue expedido en 1900s)
        let issueDateFormatted = formatExpiryMRZDate(passport.computedIssueDate)

        NSLog("[VerifyDNI] 🔵 Conversión NFC — docType:\(docTypeCode ?? "?") dni:\(dniNumber ?? "?") soporte:\(soporteNumber ?? "?") nombres:'\(givenNames ?? "?")' apellidos:'\(surnames ?? "?")' padres:'\(parents ?? "?")' nacimiento:'\(birthCity ?? "?")' dir:'\(residenceDisplay ?? "?")' expedición:'\(issueDateFormatted ?? "?")'")


        return MiDNIVerificationResult(
            isValid:               true,
            errorType:             nil,
            qrType:                nil,       // qr_type solo aplica a escaneos QR
            scanMethod:            "nfc",
            // Número real del DNI/NIE (personalNumber de DG11 o tag "53")
            documentNumber:        dniNumber,
            dateOfBirth:           formatMRZDate(passport.dateOfBirth),
            name:                  givenNames,
            surnames:              surnames,
            gender:                passport.gender.nilIfEmpty,
            documentExpiry:        formatExpiryMRZDate(passport.documentExpiryDate),
            thumbnailImageData:    photo,
            address:               residenceDisplay,
            birthPlaceLine1:       birthCity,
            birthPlaceLine2:       birthProvince,
            birthPlaceLine3:       nil,
            nationality:           passport.nationality.nilIfEmpty,
            parentsNames:          parents,
            // Número de soporte = documentNumber del MRZ (ej. "IDESP12345678")
            supportNumber:         soporteNumber,
            isAdult:               calculateIsAdult(passport.dateOfBirth),
            issueDate:             issueDateFormatted,
            signatureImageData:    signature,
            documentTypeCode:      docTypeCode,
            dataExpiryDateTime:    nil,
            verificationTimestamp: Date(),
            qrAgeSeconds:          nil
        )
    }

    // MARK: - Diagnóstico NFC

    /// Vuelca por consola TODOS los campos raw del chip NFC para diagnóstico.
    /// Esto nos permite investigar qué datos están realmente en el chip (fecha de
    /// expedición, lugar de nacimiento, número de documento, DG13, etc.).
    private func logPassportDiagnostics(_ p: NFCPassportModel) {
        NSLog("────────────────────────────────────────────────────────")
        NSLog("[CHIP DIAG] 📋 DIAGNÓSTICO COMPLETO DEL CHIP NFC")
        NSLog("────────────────────────────────────────────────────────")

        // ── Campos MRZ (DG1) ─────────────────────────────────────────────────
        NSLog("[CHIP DIAG] documentType       = '\(p.documentType)'")
        NSLog("[CHIP DIAG] documentNumber     = '\(p.documentNumber)'")
        NSLog("[CHIP DIAG] personalNumber     = '\(p.personalNumber ?? "nil")'")
        NSLog("[CHIP DIAG] dateOfBirth        = '\(p.dateOfBirth)'")
        NSLog("[CHIP DIAG] documentExpiryDate = '\(p.documentExpiryDate)'")
        NSLog("[CHIP DIAG] nationality        = '\(p.nationality)'")
        NSLog("[CHIP DIAG] gender             = '\(p.gender)'")
        NSLog("[CHIP DIAG] lastName           = '\(p.lastName)'")
        NSLog("[CHIP DIAG] firstName          = '\(p.firstName)'")
        NSLog("[CHIP DIAG] issuingAuthority   = '\(p.issuingAuthority ?? "nil")'")
        NSLog("[CHIP DIAG] passportMRZ        = '\(p.passportMRZ ?? "nil")'")

        // ── Campos DG11 (datos personales adicionales) ───────────────────────
        NSLog("[CHIP DIAG] placeOfBirth       = '\(p.placeOfBirth ?? "nil")'")
        NSLog("[CHIP DIAG] residenceAddress   = '\(p.residenceAddress ?? "nil")'")

        // ── Grupos de datos presentes ─────────────────────────────────────────
        let dgs = p.dataGroupsPresent.joined(separator: ", ")
        NSLog("[CHIP DIAG] dataGroupsPresent  = [\(dgs)]")

        // ── Fecha de expedición ─────────────────────────────────────────────────
        // computedIssueDate = SOD date (preferida) o fecha calculada por reglas
        NSLog("[CHIP DIAG] computedIssueDate  = '\(p.computedIssueDate ?? "nil")' (formatted: '\(formatMRZDate(p.computedIssueDate) ?? "nil")')")
        NSLog("[CHIP DIAG] SOD present?        = \(p.dataGroupsRead[.SOD] != nil ? "SÍ" : "NO")")

        // ── DG13 completo (datos específicos DNI español) ─────────────────────
        if let dg13 = p.dataGroupsRead[.DG13] {
            let raw = dg13.data
            NSLog("[CHIP DIAG] DG13 raw bytes (\(raw.count)): \(raw.prefix(64).map { String(format: "%02X", $0) }.joined(separator: " "))…")

            // Parsear todos los campos pipe-separated para investigación
            let allFields = dg13AllFields(dg13.data)
            for (i, field) in allFields.enumerated() {
                if !field.isEmpty {
                    NSLog("[CHIP DIAG] DG13[\(i)] = '\(field)'")
                }
            }
        } else {
            NSLog("[CHIP DIAG] DG13 = NO DISPONIBLE (no leído o no presente)")
        }

        // ── DG11 raw (si está disponible) ─────────────────────────────────────
        if let dg11 = p.dataGroupsRead[.DG11] {
            let raw = dg11.data
            NSLog("[CHIP DIAG] DG11 raw bytes (\(raw.count)): \(raw.prefix(64).map { String(format: "%02X", $0) }.joined(separator: " "))…")
        } else {
            NSLog("[CHIP DIAG] DG11 = NO DISPONIBLE")
        }

        NSLog("────────────────────────────────────────────────────────")
    }

    /// Extrae TODOS los campos pipe-separated de DG13 (para diagnóstico completo).
    private func dg13AllFields(_ raw: [UInt8]) -> [String] {
        let pipe: UInt8 = 124
        var valid: [UInt8] = []
        var i = 0
        while i < raw.count {
            let b = raw[i]
            if b >= 0x20 && b <= 0x7F {
                valid.append(b)
            } else if b >= 0xC2 && b <= 0xF4 {
                let seqLen: Int
                if      b >= 0xF0 { seqLen = 4 }
                else if b >= 0xE0 { seqLen = 3 }
                else               { seqLen = 2 }
                if i + seqLen <= raw.count {
                    valid.append(contentsOf: raw[i ..< i + seqLen])
                    i += seqLen - 1
                }
            } else {
                if valid.last != pipe { valid.append(pipe) }
            }
            i += 1
        }
        guard let str = String(bytes: valid, encoding: .utf8) else { return [] }
        return str.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    }

    // MARK: - Helpers

    /// Limpia campos de NFCPassportModel que, cuando están ausentes, devuelven "?"
    /// (el valor por defecto del diccionario interno passportDataElements) en lugar de nil.
    /// También filtra cadenas vacías.
    private func cleanPassportField(_ s: String?) -> String? {
        guard let s = s, !s.isEmpty, s != "?" else { return nil }
        return s
    }

    /// Formatea una fecha de NACIMIENTO del MRZ ("yyMMdd") → "dd-MM-yyyy".
    ///
    /// **Problema del siglo:** el MRZ almacena solo 2 dígitos del año (ej. "45"),
    /// que podría ser 1945 o 2045. La regla para resolverlo:
    ///
    ///   - Si yy > dígitos del año actual → imposible que sea este siglo (nadie
    ///     nace en el futuro) → siglo 20 (19XX).
    ///   - Si yy ≤ dígitos del año actual → podría ser este siglo → siglo 21 (20XX).
    ///
    /// Ejemplos en 2025 (currentYY = 25):
    ///   yy=45 → 45 > 25 → 1945 ✓  (persona de 80 años)
    ///   yy=30 → 30 > 25 → 1930 ✓  (persona de 95 años) ← umbral fijo "30" fallaba aquí
    ///   yy=25 → 25 > 25 es FALSE → 2025 ✓  (recién nacido)
    ///   yy=10 → 10 > 25 es FALSE → 2010 ✓  (persona de 15 años)
    ///
    /// Caso límite: alguien nacido en 1924 (101 años) tiene yy=24, que en 2025
    /// se muestra como 2024. Es un caso extremadamente raro, inevitable con 2 dígitos.
    private func formatMRZDate(_ mrzDate: String?) -> String? {
        guard let d = mrzDate, d.count == 6 else { return nil }
        let yy   = String(d.prefix(2))
        let mm   = String(d.dropFirst(2).prefix(2))
        let dd   = String(d.dropFirst(4))
        guard let yyInt = Int(yy) else { return nil }
        let currentYY = Calendar.current.component(.year, from: Date()) % 100
        let year = yyInt > currentYY ? "19\(yy)" : "20\(yy)"
        return "\(dd)-\(mm)-\(year)"
    }

    /// Formatea una fecha de CADUCIDAD del MRZ ("yyMMdd") → "dd-MM-yyyy".
    ///
    /// Difiere de `formatMRZDate` en dos aspectos:
    ///   1. DNI permanente (personas ≥ 70 años) — el chip codifica la caducidad
    ///      con año "99" (ej. "991231"). Devuelve "Permanente" en lugar de fecha.
    ///   2. Todos los demás casos → SIEMPRE siglo 21, porque ningún documento
    ///      válido caduca en los años 1900. Esto evita que 2031 se muestre como
    /// Formatea una fecha de CADUCIDAD del MRZ ("yyMMdd") → "dd-MM-yyyy".
    ///
    /// - yy == "99" → año 9999 (DNI permanente para ≥ 70 años).
    ///   La DGP codifica la caducidad como "990101" en el chip, que representa el
    ///   año 9999. Devolvemos "01-01-9999" para que la UI lo muestre como
    ///   "Sin caducidad" al detectar year ≥ 9000.
    ///
    /// - Resto → siempre siglo 21, porque ningún DNI válido caduca en los 1900.
    ///   Esto corrige que yy=31 (2031) no se muestre erróneamente como "1931".
    private func formatExpiryMRZDate(_ mrzDate: String?) -> String? {
        guard let d = mrzDate, d.count == 6 else { return nil }
        let yy = String(d.prefix(2))
        let mm = String(d.dropFirst(2).prefix(2))
        let dd = String(d.dropFirst(4))
        if yy == "99" { return "\(dd)-\(mm)-9999" }    // DNI permanente → año 9999
        return "\(dd)-\(mm)-20\(yy)"                   // siempre siglo 21
    }

    private func calculateIsAdult(_ dobMRZ: String?) -> Bool? {
        guard let formatted = formatMRZDate(dobMRZ) else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "dd-MM-yyyy"
        fmt.locale     = Locale(identifier: "en_US_POSIX")
        guard let date = fmt.date(from: formatted) else { return nil }
        return (Calendar(identifier: .gregorian)
            .dateComponents([.year], from: date, to: Date()).year ?? 0) >= 18
    }

    // MARK: - Error mapping con diagnóstico de tiempo

    private func mapError(_ error: Error, elapsed: TimeInterval = 60) -> NFCReadError {
        let desc = error.localizedDescription.lowercased()

        NSLog("[VerifyDNI] 🔴 mapError — elapsed=\(String(format: "%.1f", elapsed))s | desc='\(desc)'")

        // ─── Cancelación explícita — puede ocurrir en cualquier momento ─────────
        if desc.contains("usercanceled") || desc.contains("user cancel")
            || desc.contains("cancelled") || desc.contains("invalidated by user") {
            return .readCancelled
        }

        // ─── Dispositivo sin soporte NFC ────────────────────────────────────────
        if desc.contains("nfcnotsupported") || desc.contains("not supported") {
            return .unsupportedDevice
        }

        // ─── Conexión perdida o hardware ocupado ────────────────────────────────
        // "connectionerror"  = NFCPassportReaderError.ConnectionError que envuelve:
        //   • NFCError Code=100 "Tag connection lost"   (chip encontrado, se cae mid-read)
        //   • NFCError Code="Tag response error / no response" (chip no responde)
        // Ambos necesitan el mismo remedio: esperar ~5s y reintentar.
        if desc.contains("tag lost") || desc.contains("tag connection lost")
            || desc.contains("taglost") || desc.contains("connectionerror") {
            return .tagLost
        }

        // ─── Hardware NFC ocupado (System resource unavailable, Code=203) ───────
        // NFCPassportReader lo envuelve como "UnexpectedError" con elapsed muy bajo.
        // NUNCA es un problema de entitlement — el hardware simplemente necesita
        // unos segundos de enfriamiento entre sesiones.
        // NOTA: "UnexpectedError" con elapsed alto es un timeout real (chip no hallado).
        if desc.contains("unexpectederror") || desc.contains("unexpected") {
            if elapsed < 5 {
                NSLog("[VerifyDNI] ⚠️  UnexpectedError inmediato (\(String(format: "%.1f", elapsed))s) → System resource unavailable")
                return .tagLost  // mismo remedio: esperar y reintentar
            }
            return .timeout
        }

        // ─── Entitlement / provisioning ausente ─────────────────────────────────
        // Solo llegamos aquí si elapsed < 5s y la descripción no encaja en ninguno
        // de los casos anteriores. Indica un error de configuración del proyecto.
        if elapsed < 5 {
            NSLog("[VerifyDNI] ⚠️  Error inmediato (\(String(format: "%.1f", elapsed))s) — posible problema de entitlement")
            return .permissionError
        }

        // ─── Resto ──────────────────────────────────────────────────────────────
        if desc.contains("timeout") || desc.contains("time out") || desc.contains("session timeout") {
            return .timeout
        }
        if desc.contains("invalidmrzkey") || desc.contains("invalid mrz") || desc.contains("wrong key") {
            return .invalidMRZ
        }
        if desc.contains("notag") || desc.contains("no tag") || desc.contains("noconnectedtag") {
            return .chipNotFound
        }
        return .unknown(error.localizedDescription)
    }
}
