// MiDNIParser.swift
// VerifyDNI
//
// Componente central del sistema de verificación MiDNI.
// Orquesta C40Decoder + CertificateManager + ECDSAVerifier
// para producir un MiDNIVerificationResult completo.
//
// Especificación: "Verificación y Formato de Códigos QR DNI en el
// Móvil" v1.0.7 — Policía Nacional de España (ICAO 9303 parte 13)
//
// IMPORTANTE: parse() es async. Llamar siempre desde un Task
// en background, nunca desde el hilo principal.

import Foundation

// MARK: - MiDNIParser

/// Namespace puro (enum sin casos) para el parseo y verificación de QRs MiDNI.
///
/// ### Flujo de verificación (orden estricto)
/// 1. Verificar magic constant `0xDC`
/// 2. Verificar versión `0x03`
/// 3. Parsear cabecera C40 → extraer tipo de QR y referencia del certificado
/// 4. Obtener clave pública desde `CertificateManager`
/// 5. Comparar serial del certificado con referencia del QR
/// 6. Verificar firma ECDSA SHA-256 (`ECDSAVerifier`)
/// 7. Parsear TLVs del cuerpo
/// 8. Extraer y validar fecha de caducidad (tag `0x80`)
/// 9. Construir `MiDNIVerificationResult` con `isValid = true`
enum MiDNIParser {

    // MARK: - API pública

    /// Parsea y verifica un QR MiDNI completo.
    ///
    /// - Parameter qrData: Bytes raw del QR tal como los entrega ML Kit
    ///   a través de `barcode.rawData`. **No pasar `rawValue` (String).**
    /// - Returns: `MiDNIVerificationResult` con todos los campos disponibles
    ///   según el tipo de QR.
    /// - Throws: `MiDNIError` en cualquier punto del procedimiento.
    ///
    /// El llamador (`ScannerViewModel`) captura el error y construye un
    /// resultado con `isValid = false`. `MiDNIParser` nunca retorna un
    /// resultado con `isValid = false` — sólo lanza o retorna `true`.
    static func parse(_ qrData: Data) async throws -> MiDNIVerificationResult {
        let bytes = [UInt8](qrData)

        // ── Paso 1: Magic constant ────────────────────────────────────────────
        guard bytes.count > 1 else { throw MiDNIError.malformedHeader }
        guard bytes[0] == 0xDC else {
            #if DEBUG
            print("[MiDNIParser] ✗ Paso 1: magic byte inválido 0x\(String(bytes[0], radix: 16))")
            #endif
            throw MiDNIError.invalidMagicConstant
        }
        #if DEBUG
        print("[MiDNIParser] ✓ Paso 1: magic 0xDC correcto")
        #endif

        // ── Paso 2: Versión ───────────────────────────────────────────────────
        guard bytes[1] == 0x03 else {
            #if DEBUG
            print("[MiDNIParser] ✗ Paso 2: versión inválida 0x\(String(bytes[1], radix: 16))")
            #endif
            throw MiDNIError.unsupportedVersion
        }
        #if DEBUG
        print("[MiDNIParser] ✓ Paso 2: versión 0x03 correcta")
        #endif

        // ── Paso 3: Parsear cabecera ──────────────────────────────────────────
        let (headerSize, qrType, certReference) = try parseHeader(bytes)
        #if DEBUG
        print("[MiDNIParser] ✓ Paso 3: cabecera parseada")
        print("             headerSize=\(headerSize), qrType=\(qrType), certRef=\(certReference)")
        #endif

        // ── Paso 4: Cargar certificados disponibles ──────────────────────────
        // CertificateManager carga el cert de red Y el del bundle.
        // Ambos quedan indexados por su serial en _certificates.
        try await CertificateManager.shared.loadCertificate()
        #if DEBUG
        print("[MiDNIParser] ✓ Paso 4: certificados cargados")
        #endif

        // ── Paso 5: Obtener clave pública del cert que coincide con el QR ────
        // getPublicKey(forSerial:) busca en todos los certs disponibles
        // (red + bundle) el que tiene el serial referenciado en la cabecera.
        // Si la Policía ha rotado el cert en el servidor pero el QR fue
        // generado con el cert anterior (embebido en el bundle), esto funciona.
        #if DEBUG
        print("[MiDNIParser]   buscando cert con serial: \(certReference)")
        #endif
        let publicKey = try await CertificateManager.shared.getPublicKey(forSerial: certReference)
        #if DEBUG
        print("[MiDNIParser] ✓ Paso 5: clave pública del cert \(certReference) obtenida")
        #endif

        // ── Paso 6: Verificar firma ECDSA ─────────────────────────────────────
        try ECDSAVerifier.verify(qrBytes: qrData, publicKey: publicKey)
        #if DEBUG
        print("[MiDNIParser] ✓ Paso 6: firma ECDSA SHA-256 válida")
        #endif

        // ── Paso 7: Parsear TLVs del cuerpo ──────────────────────────────────
        let tlvs = try parseTLVs(bytes, from: headerSize)
        #if DEBUG
        print("[MiDNIParser] ✓ Paso 7: \(tlvs.count) TLVs parseados")
        for (tag, data) in tlvs.sorted(by: { $0.key < $1.key }) {
            let preview: String
            if tag == 0x50 {
                preview = "<imagen \(data.count) bytes JPEG2000>"
            } else {
                preview = String(data: data, encoding: .utf8) ?? data.map { String(format: "%02X", $0) }.joined()
            }
            print("             tag 0x\(String(tag, radix: 16, uppercase: true)): \(preview)")
        }
        #endif

        // ── Paso 8: Extraer y validar fecha de caducidad (tag 0x80) ──────────
        guard let expiryData   = tlvs[0x80],
              let expiryString = String(data: expiryData, encoding: .utf8) else {
            #if DEBUG
            print("[MiDNIParser] ✗ Paso 8: tag 0x80 no encontrado o no es UTF-8")
            #endif
            throw MiDNIError.malformedTLV
        }

        guard let expiryDate = parseExpiryDate(expiryString) else {
            #if DEBUG
            print("[MiDNIParser] ✗ Paso 8: fecha de caducidad con formato inválido: \(expiryString)")
            #endif
            throw MiDNIError.malformedTLV
        }

        let now = Date()
        if now > expiryDate {
            let secondsAgo = Int(now.timeIntervalSince(expiryDate))
            #if DEBUG
            print("[MiDNIParser] ✗ Paso 8: QR caducado hace \(secondsAgo)s (expiró \(expiryString) UTC)")
            #endif
            throw MiDNIError.expiredQR(secondsAgo: secondsAgo)
        }
        #if DEBUG
        let remaining = Int(expiryDate.timeIntervalSince(now))
        print("[MiDNIParser] ✓ Paso 8: QR válido, caduca en \(remaining)s (\(expiryString) UTC)")
        #endif

        // ── Paso 9: Extraer campos y construir resultado ──────────────────────
        let fields = extractFields(from: tlvs, qrType: qrType, expiryDate: expiryDate)
        #if DEBUG
        print("[MiDNIParser] ✓ Paso 9: campos extraídos, construyendo resultado final")
        #endif

        return MiDNIVerificationResult(
            isValid:              true,
            errorType:            nil,
            qrType:               qrType,
            scanMethod:           "qr",
            documentNumber:       fields.documentNumber,
            dateOfBirth:          fields.dateOfBirth,
            name:                 fields.name,
            surnames:             fields.surnames,
            gender:               fields.gender,
            documentExpiry:       fields.documentExpiry,
            thumbnailImageData:   fields.thumbnailImageData,
            address:              fields.address,
            birthPlaceLine1:      fields.birthPlaceLine1,
            birthPlaceLine2:      fields.birthPlaceLine2,
            birthPlaceLine3:      fields.birthPlaceLine3,
            // El QR MiDNI solo existe para DNI español →
            // si el tag 0x64 no está presente, asumimos "ESP".
            nationality:          fields.nationality ?? "ESP",
            parentsNames:         fields.parentsNames,
            supportNumber:        fields.supportNumber,
            isAdult:              fields.isAdult,
            issueDate:            nil,   // no disponible en QR
            signatureImageData:   nil,   // no disponible en QR
            // El QR MiDNI es exclusivo del DNI español emitido por la
            // Policía Nacional. El código ICAO 9303 para tarjetas de
            // identidad (TD1) es "I", igual que el chip NFC del DNI.
            documentTypeCode:     "I",
            dataExpiryDateTime:   expiryDate,
            verificationTimestamp: now,
            qrAgeSeconds:         nil   // no calculable desde el QR (ver spec §4.2)
        )
    }

    // MARK: - Parseo de cabecera

    /// Parsea la cabecera del QR MiDNI y extrae tipo de QR y referencia del certificado.
    ///
    /// ### Estructura de la cabecera
    /// ```
    /// [0x00] 1 byte  magic=0xDC         (ya verificado)
    /// [0x01] 1 byte  version=0x03       (ya verificado)
    /// [0x02] 2 bytes país en C40        → "ES"
    /// [0x04] v bytes firmante+referencia en C40
    ///              └─ 4 bytes  signerID → "ESPN20" (país+entidad+tamaño_ref_hex)
    ///              └─ k bytes  referencia certificado (k = ceil(refSize/3)*2)
    /// [4+v]  3 bytes fecha emisión documento (ICAO, ignorar)
    /// [7+v]  3 bytes fecha creación firma (ICAO, ignorar)
    /// [10+v] 1 byte  tipo QR: 7=simple, 8=completo, 9=edad
    /// [11+v] 1 byte  categoría: 9=DNI España
    /// ```
    private static func parseHeader(
        _ bytes: [UInt8]
    ) throws -> (headerSize: Int, qrType: QRType, certReference: String) {

        guard bytes.count > 4 else { throw MiDNIError.malformedHeader }

        #if DEBUG
        let headerPreview = bytes.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")
        print("[MiDNIParser] Primeros 16 bytes: \(headerPreview)")
        #endif

        // ── País (offset 0x02): 2 bytes C40 → "ES" ──────────────────────────
        let countryData = Data(bytes[2..<4])
        let country: String
        do {
            country = try C40Decoder.decode(countryData, taking: 2)
        } catch {
            #if DEBUG
            print("[MiDNIParser] ✗ C40 falló al decodificar país: \(error) — bytes: \(bytes[2..<4].map { String(format: "%02X", $0) })")
            #endif
            throw MiDNIError.malformedHeader
        }
        guard country == "ES" else {
            #if DEBUG
            print("[MiDNIParser] País inesperado: \(country)")
            #endif
            throw MiDNIError.malformedHeader
        }

        // ── Identificador firmante (offset 0x04): 4 bytes C40 → 6 chars ─────
        // Formato: país(2) + entidad(2) + tamaño_ref_hex(2)
        // Ejemplo: "ESPN20" → país="ES", entidad="PN", refSize=0x20=32 chars
        guard bytes.count >= 8 else { throw MiDNIError.malformedHeader }
        let signerIdData = Data(bytes[4..<8])
        let signerIdStr: String
        do {
            signerIdStr = try C40Decoder.decode(signerIdData)
        } catch {
            #if DEBUG
            print("[MiDNIParser] ✗ C40 falló al decodificar signerID: \(error) — bytes: \(bytes[4..<8].map { String(format: "%02X", $0) })")
            #endif
            throw MiDNIError.malformedHeader
        }
        #if DEBUG
        print("[MiDNIParser]   signerID decodificado: \(signerIdStr)")
        #endif

        // Los 2 últimos caracteres son el tamaño de la referencia en hex
        let refSizeHex = String(signerIdStr.suffix(2))
        guard let refSizeChars = Int(refSizeHex, radix: 16), refSizeChars > 0 else {
            #if DEBUG
            print("[MiDNIParser] ✗ refSizeHex inválido: '\(refSizeHex)' de signerID '\(signerIdStr)'")
            #endif
            throw MiDNIError.malformedHeader
        }

        // ── Referencia del certificado ────────────────────────────────────────
        // Número de bytes C40 para codificar refSizeChars caracteres:
        // ((n + 2) / 3) * 2  con aritmética entera = ceil(n/3) * 2
        let refC40Bytes = ((refSizeChars + 2) / 3) * 2

        let refStart = 8
        let refEnd   = refStart + refC40Bytes
        guard bytes.count >= refEnd else { throw MiDNIError.malformedHeader }

        let refData = Data(bytes[refStart..<refEnd])
        let certReference: String
        do {
            certReference = try C40Decoder.decode(refData, taking: refSizeChars)
        } catch {
            #if DEBUG
            print("[MiDNIParser] ✗ C40 falló al decodificar certReference: \(error)")
            print("             refSizeChars=\(refSizeChars), refC40Bytes=\(refC40Bytes)")
            print("             bytes: \(refData.map { String(format: "%02X", $0) }.joined(separator: " "))")
            #endif
            throw MiDNIError.malformedHeader
        }

        // ── Offsets post-referencia ───────────────────────────────────────────
        // v = bytes del campo firmante desde offset 4
        //   = 4 (signerID) + refC40Bytes
        let v = 4 + refC40Bytes

        // +6 = 3 bytes fecha emisión + 3 bytes fecha creación firma (ICAO, ignorar)
        let qrTypeOffset = 4 + v + 6
        guard bytes.count > qrTypeOffset + 1 else {
            throw MiDNIError.malformedHeader
        }

        // ── Tipo de QR ────────────────────────────────────────────────────────
        let qrTypeByte = bytes[qrTypeOffset]
        guard let qrType = QRType(rawValue: Int(qrTypeByte)) else {
            #if DEBUG
            print("[MiDNIParser] Tipo de QR desconocido: 0x\(String(qrTypeByte, radix: 16))")
            #endif
            throw MiDNIError.malformedHeader
        }

        // ── Categoría (DNI España = 9) ────────────────────────────────────────
        let categoryOffset = qrTypeOffset + 1
        guard bytes.count > categoryOffset else {
            throw MiDNIError.malformedHeader
        }
        guard bytes[categoryOffset] == 0x09 else {
            #if DEBUG
            print("[MiDNIParser] Categoría inesperada: 0x\(String(bytes[categoryOffset], radix: 16))")
            #endif
            throw MiDNIError.malformedHeader
        }

        let headerSize = categoryOffset + 1
        return (headerSize, qrType, certReference)
    }

    // MARK: - Parseo de TLVs del cuerpo

    /// Parsea la secuencia de TLVs del cuerpo del QR desde `offset` hasta
    /// encontrar el tag `0xFF` (inicio del TLV de firma) o el final del array.
    ///
    /// ### Formato TLV (BER-TLV estándar)
    /// ```
    /// [tag: 1 byte] [length: 1-3 bytes BER] [value: N bytes]
    /// ```
    ///
    /// - Parameters:
    ///   - bytes: Bytes completos del QR.
    ///   - offset: Posición de inicio (igual a `headerSize`).
    /// - Returns: Diccionario `[tag → Data]` con los valores de cada campo.
    private static func parseTLVs(
        _ bytes: [UInt8],
        from offset: Int
    ) throws -> [UInt8: Data] {

        var result = [UInt8: Data]()
        var i = offset

        while i < bytes.count {
            let tag = bytes[i]

            // El tag 0xFF marca el inicio del TLV de firma → fin del cuerpo
            if tag == 0xFF { break }

            guard i + 1 < bytes.count else { break }

            let (length, lenBytes) = ECDSAVerifier.readBERLength(bytes, at: i + 1)
            guard length >= 0, lenBytes > 0 else {
                #if DEBUG
                print("[MiDNIParser] TLV malformado en offset \(i): tag=0x\(String(tag, radix: 16, uppercase: true))")
                #endif
                throw MiDNIError.malformedTLV
            }

            let valueStart = i + 1 + lenBytes
            let valueEnd   = valueStart + length

            guard valueEnd <= bytes.count else {
                #if DEBUG
                print("[MiDNIParser] TLV truncado en offset \(i): tag=0x\(String(tag, radix: 16, uppercase: true)), len=\(length)")
                #endif
                throw MiDNIError.malformedTLV
            }

            // Guardar el valor (tag duplicado → el último gana)
            result[tag] = Data(bytes[valueStart..<valueEnd])
            i = valueEnd
        }

        return result
    }

    // MARK: - Extracción de campos del resultado

    /// Convierte el diccionario de TLVs a los campos del `MiDNIVerificationResult`.
    ///
    /// - Strings: decodificados como UTF-8 (el body del QR usa UTF-8, no C40).
    /// - Imagen (tag 0x50): `Data` directa en formato JPEG2000.
    /// - Bool (tag 0x70): `0x01 = true`, `0x00 = false`.
    /// - `isAdult`: si tag 0x70 no existe, se calcula desde fecha de nacimiento.
    private static func extractFields(
        from tlvs: [UInt8: Data],
        qrType: QRType,
        expiryDate: Date
    ) -> (
        documentNumber:    String?,
        dateOfBirth:       String?,
        name:              String?,
        surnames:          String?,
        gender:            String?,
        documentExpiry:    String?,
        thumbnailImageData: Data?,
        address:           String?,
        birthPlaceLine1:   String?,
        birthPlaceLine2:   String?,
        birthPlaceLine3:   String?,
        nationality:       String?,
        parentsNames:      String?,
        supportNumber:     String?,
        isAdult:           Bool?
    ) {
        // ── Campos de texto (UTF-8) ───────────────────────────────────────────
        let documentNumber  = tlvs[0x40].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)
        let dateOfBirth     = tlvs[0x42].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)
        let name            = tlvs[0x44].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)
        let surnames        = tlvs[0x46].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)
        let gender          = tlvs[0x48].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)
        let documentExpiry  = tlvs[0x4C].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)

        // ── Imagen JPEG2000 (tag 0x50) — Data directa ────────────────────────
        let thumbnailImageData = tlvs[0x50]

        // ── Campos QR tipo completo (8) ───────────────────────────────────────
        let address         = tlvs[0x60].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)
        let birthPlaceLine1 = tlvs[0x62].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)
        let nationality     = tlvs[0x64].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)
        let parentsNames    = tlvs[0x66].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)
        let supportNumber   = tlvs[0x68].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)
        let birthPlaceLine2 = tlvs[0x78].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)
        let birthPlaceLine3 = tlvs[0x7A].flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespaces)

        // ── Mayoría de edad (tag 0x70 o calculado desde fecha de nacimiento) ──
        let isAdult: Bool?
        if let adultData = tlvs[0x70] {
            // Tag explícito: 0x01=mayor, 0x00=menor
            isAdult = adultData.first == 0x01
        } else if let dob = dateOfBirth {
            // Calcular desde "DD-MM-YYYY"
            isAdult = calculateIsAdult(from: dob)
        } else {
            isAdult = nil
        }

        return (
            documentNumber:    documentNumber,
            dateOfBirth:       dateOfBirth,
            name:              name,
            surnames:          surnames,
            gender:            gender,
            documentExpiry:    documentExpiry,
            thumbnailImageData: thumbnailImageData,
            address:           address,
            birthPlaceLine1:   birthPlaceLine1,
            birthPlaceLine2:   birthPlaceLine2,
            birthPlaceLine3:   birthPlaceLine3,
            nationality:       nationality,
            parentsNames:      parentsNames,
            supportNumber:     supportNumber,
            isAdult:           isAdult
        )
    }

    // MARK: - Helpers privados

    /// Parsea la fecha de caducidad del tag `0x80`.
    ///
    /// Formato esperado: `"DD-MM-YYYY hh:mm:ss"` en UTC.
    private static func parseExpiryDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
        formatter.timeZone   = TimeZone(identifier: "UTC")
        formatter.locale     = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string.trimmingCharacters(in: .whitespaces))
    }

    /// Calcula mayoría de edad a partir de la fecha de nacimiento en formato
    /// `"DD-MM-YYYY"`. Usa el calendario gregoriano y la fecha actual del dispositivo.
    private static func calculateIsAdult(from dobString: String) -> Bool? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale     = Locale(identifier: "en_US_POSIX")
        formatter.timeZone   = TimeZone(identifier: "UTC")

        guard let dob = formatter.date(from: dobString) else { return nil }

        let calendar     = Calendar(identifier: .gregorian)
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        guard let age = ageComponents.year else { return nil }

        return age >= 18
    }
}

// MARK: - Tests unitarios (#if DEBUG)

#if DEBUG

/// Tests del `MiDNIParser` que validan la lógica de parseo sin requerir
/// un QR real firmado (los tests de integración con QR real se realizan
/// en el simulador con los QRs de prueba de la Policía Nacional).
enum MiDNIParserTests {

    @discardableResult
    static func runAll() -> Bool {
        print("═══════════════════════════════════════════════")
        print("  MiDNIParser — Tests Unitarios")
        print("═══════════════════════════════════════════════")

        var passed = 0
        var failed = 0

        func pass(_ d: String) { print("[PASS] \(d)"); passed += 1 }
        func fail(_ d: String, _ r: String = "") {
            print("[FAIL] \(d)\(r.isEmpty ? "" : " — \(r)")")
            failed += 1
        }

        // ── Test 1: magic constant ────────────────────────────────────────────
        let badMagic = Data([0xAB, 0x03])
        Task {
            do {
                _ = try await MiDNIParser.parse(badMagic)
                fail("magic inválido debería lanzar")
            } catch MiDNIError.invalidMagicConstant {
                pass("magic inválido → invalidMagicConstant")
            } catch { fail("magic inválido error inesperado", "\(error)") }
        }

        // ── Test 2: versión ───────────────────────────────────────────────────
        let badVersion = Data([0xDC, 0x04])
        Task {
            do {
                _ = try await MiDNIParser.parse(badVersion)
                fail("versión inválida debería lanzar")
            } catch MiDNIError.unsupportedVersion {
                pass("versión inválida → unsupportedVersion")
            } catch { fail("versión inválida error inesperado", "\(error)") }
        }

        // ── Test 3: parseExpiryDate ───────────────────────────────────────────
        let validDateStr  = "17-04-2034 12:30:00"
        let expiredStr    = "01-01-2020 00:00:00"
        let badFormatStr  = "2034/04/17 12:30:00"

        if parseExpiryDatePublic(validDateStr) != nil {
            pass("parseExpiryDate válida: \(validDateStr)")
        } else {
            fail("parseExpiryDate válida devuelve nil")
        }

        if parseExpiryDatePublic(expiredStr) != nil {
            pass("parseExpiryDate caducada: \(expiredStr)")
        } else {
            fail("parseExpiryDate caducada devuelve nil")
        }

        if parseExpiryDatePublic(badFormatStr) == nil {
            pass("parseExpiryDate formato incorrecto devuelve nil")
        } else {
            fail("parseExpiryDate formato incorrecto debería ser nil")
        }

        // ── Test 4: calculateIsAdult ──────────────────────────────────────────
        let adultDOB  = "01-01-1990"  // >18
        let minorDOB  = "01-01-2020"  // <18
        let futureDOB = "01-01-2080"  // futuro

        if calculateIsAdultPublic(adultDOB) == true {
            pass("isAdult 1990 → true")
        } else {
            fail("isAdult 1990 debería ser true")
        }

        if calculateIsAdultPublic(minorDOB) == false {
            pass("isAdult 2020 → false")
        } else {
            fail("isAdult 2020 debería ser false")
        }

        if calculateIsAdultPublic(futureDOB) == false {
            pass("isAdult 2080 → false")
        } else {
            fail("isAdult 2080 debería ser false o nil")
        }

        // ── Test 5: parseTLVs básico ──────────────────────────────────────────
        // Construir TLVs manuales y verificar parseo
        let sampleTLVs = buildSampleTLVs()
        do {
            let result = try parseTLVsPublic(sampleTLVs, from: 0)
            if result[0x40] != nil {
                pass("parseTLVs: tag 0x40 extraído correctamente")
            } else {
                fail("parseTLVs: tag 0x40 no encontrado")
            }
            if result[0x50] != nil {
                pass("parseTLVs: tag 0x50 (imagen) extraído correctamente")
            } else {
                fail("parseTLVs: tag 0x50 no encontrado")
            }
            if result[0xFF] == nil {
                pass("parseTLVs: tag 0xFF no incluido en el diccionario (es firma)")
            } else {
                fail("parseTLVs: tag 0xFF no debería estar en el diccionario")
            }
        } catch {
            fail("parseTLVs", "\(error)")
        }

        // ── Test 6: MiDNIVerificationResult helpers ───────────────────────────
        let mockResult = MiDNIVerificationResult(
            isValid: true, errorType: nil, qrType: .simple,
            scanMethod: "qr",
            documentNumber: "12345678Z", dateOfBirth: "01-01-1980",
            name: "CARMEN", surnames: "ESPAÑOLA ESPAÑOLA",
            gender: "F", documentExpiry: "17-04-2034",
            thumbnailImageData: nil,
            address: nil, birthPlaceLine1: nil, birthPlaceLine2: nil,
            birthPlaceLine3: nil, nationality: nil, parentsNames: nil,
            supportNumber: nil, isAdult: true,
            issueDate: nil, signatureImageData: nil, documentTypeCode: nil,
            dataExpiryDateTime: parseExpiryDatePublic("17-04-2034 12:30:00"),
            verificationTimestamp: Date(), qrAgeSeconds: nil
        )
        if mockResult.fullName == "CARMEN ESPAÑOLA ESPAÑOLA" {
            pass("fullName = 'CARMEN ESPAÑOLA ESPAÑOLA'")
        } else {
            fail("fullName", "got '\(mockResult.fullName ?? "nil")'")
        }
        if mockResult.secondsUntilExpiry != nil {
            pass("secondsUntilExpiry calculado")
        } else {
            fail("secondsUntilExpiry nil cuando hay fecha de caducidad")
        }

        print("───────────────────────────────────────────────")
        print("  Resultado: \(passed) pasados, \(failed) fallidos de \(passed + failed) tests")
        print("═══════════════════════════════════════════════")
        return failed == 0
    }

    // ── Réplicas públicas de funciones privadas para tests ───────────────────

    static func parseExpiryDatePublic(_ s: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd-MM-yyyy HH:mm:ss"
        fmt.timeZone   = TimeZone(identifier: "UTC")
        fmt.locale     = Locale(identifier: "en_US_POSIX")
        return fmt.date(from: s)
    }

    static func calculateIsAdultPublic(_ dob: String) -> Bool? {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd-MM-yyyy"
        fmt.locale     = Locale(identifier: "en_US_POSIX")
        fmt.timeZone   = TimeZone(identifier: "UTC")
        guard let d = fmt.date(from: dob) else { return nil }
        let age = Calendar(identifier: .gregorian)
            .dateComponents([.year], from: d, to: Date()).year
        return (age ?? 0) >= 18
    }

    static func parseTLVsPublic(_ bytes: [UInt8], from offset: Int) throws -> [UInt8: Data] {
        var result = [UInt8: Data]()
        var i = offset
        while i < bytes.count {
            let tag = bytes[i]
            if tag == 0xFF { break }
            guard i + 1 < bytes.count else { break }
            let (len, lenB) = ECDSAVerifier.readBERLength(bytes, at: i + 1)
            guard len >= 0, lenB > 0 else { throw MiDNIError.malformedTLV }
            let vs = i + 1 + lenB, ve = vs + len
            guard ve <= bytes.count else { throw MiDNIError.malformedTLV }
            result[tag] = Data(bytes[vs..<ve])
            i = ve
        }
        return result
    }

    private static func buildSampleTLVs() -> [UInt8] {
        func tlv(_ tag: UInt8, _ value: [UInt8]) -> [UInt8] {
            [tag, UInt8(value.count)] + value
        }
        let docNum   = Array("12345678Z ".utf8)
        let name     = Array("CARMEN".utf8)
        let imageData = [UInt8](repeating: 0xAB, count: 30)
        let expiry   = Array("17-04-2034 12:30:00".utf8)
        let sigData  = [UInt8](repeating: 0x01, count: 64)

        var bytes = [UInt8]()
        bytes += tlv(0x40, docNum)
        bytes += tlv(0x44, name)
        bytes += tlv(0x50, imageData)
        bytes += tlv(0x80, expiry)
        bytes += [0xFF, UInt8(sigData.count)] + sigData  // firma (no entra en dict)
        return bytes
    }
}

#endif
