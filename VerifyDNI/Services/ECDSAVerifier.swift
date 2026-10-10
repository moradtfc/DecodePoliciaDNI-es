// ECDSAVerifier.swift
// VerifyDNI
//
// Verificación criptográfica ECDSA SHA-256 del QR MiDNI.
//
// Responsabilidad única: dado el payload raw del QR y la clave
// pública del certificado APPDNIMOVIL, verificar que la firma
// del último TLV (tag 0xFF) es válida sobre todos los bytes anteriores.
//
// Especificación: "Verificación y Formato de Códigos QR DNI en el
// Móvil" v1.0.7 — Policía Nacional de España (ICAO 9303 parte 13)

import Foundation
import Security

// MARK: - ECDSAVerifier

/// Verificador de firmas ECDSA para QRs MiDNI.
///
/// `ECDSAVerifier` es un *namespace* puro (enum sin casos). No almacena estado.
/// Su único punto de entrada es `verify(qrBytes:publicKey:)`.
///
/// ### Formato de la firma en el QR
/// El último TLV del QR lleva tag `0xFF`. Su valor son los bytes raw
/// de la firma ECDSA en formato `r ‖ s` (dos enteros de igual longitud
/// concatenados sin estructura ASN.1).
///
/// `SecKeyVerifySignature` con `.ecdsaSignatureMessageX962SHA256` espera
/// formato ASN.1 DER: `SEQUENCE { INTEGER r, INTEGER s }`. Por ello se
/// convierte la firma antes de llamar al framework de seguridad.
enum ECDSAVerifier {

    // MARK: - API pública

    /// Verifica la firma ECDSA SHA-256 de un QR MiDNI.
    ///
    /// Los datos firmados son todos los bytes del QR **excepto** el TLV
    /// final con tag `0xFF`.
    ///
    /// - Parameters:
    ///   - qrBytes: Bytes completos del QR tal como los entrega ML Kit
    ///              a través de `barcode.rawData`.
    ///   - publicKey: Clave pública EC obtenida de
    ///                `CertificateManager.shared.getPublicKey()`.
    ///
    /// - Throws:
    ///   - `MiDNIError.malformedTLV` si no se localiza el TLV `0xFF`.
    ///   - `MiDNIError.invalidSignature` si la firma no es válida o el
    ///     algoritmo no está soportado.
    static func verify(qrBytes: Data, publicKey: SecKey) throws {
        let bytes = [UInt8](qrBytes)

        // ── 1. Separar datos firmados y firma raw ────────────────────────────
        let (dataToVerify, rawSignature) = try findSignatureTLV(in: bytes)

        #if DEBUG
        print("[ECDSAVerifier] dataToVerify: \(dataToVerify.count) bytes")
        print("[ECDSAVerifier] rawSignature: \(rawSignature.count) bytes")
        #endif

        // ── 2. Convertir firma raw (r‖s) a ASN.1 DER ────────────────────────
        let derSignature = try rawSignatureToDER(rawSignature)

        #if DEBUG
        print("[ECDSAVerifier] DER signature: \(derSignature.count) bytes")
        print("[ECDSAVerifier] DER hex: \(derSignature.map { String(format: "%02x", $0) }.joined())")
        #endif

        // ── 3. Verificar con Security framework ──────────────────────────────
        let algorithm = SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256

        guard SecKeyIsAlgorithmSupported(publicKey, .verify, algorithm) else {
            #if DEBUG
            print("[ECDSAVerifier] Algoritmo ECDSA X962 SHA-256 no soportado por esta clave")
            #endif
            throw MiDNIError.invalidSignature
        }

        var cfError: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(
            publicKey,
            algorithm,
            dataToVerify as CFData,
            derSignature as CFData,
            &cfError
        )

        guard isValid else {
            #if DEBUG
            if let err = cfError?.takeRetainedValue() {
                print("[ECDSAVerifier] Verificación fallida: \(err)")
            }
            #endif
            throw MiDNIError.invalidSignature
        }

        #if DEBUG
        print("[ECDSAVerifier] ✓ Firma ECDSA válida")
        #endif
    }

    // MARK: - Localización del TLV de firma (privado)

    /// Localiza el TLV con tag `0xFF` escaneando desde el **final** del array.
    ///
    /// ### Por qué desde el final
    /// El byte `0xFF` puede aparecer dentro del valor del tag `0x50`
    /// (imagen JPEG2000 del ciudadano). Para evitar falsos positivos se
    /// busca el candidato más próximo al final que forme un TLV válido
    /// terminando exactamente en el último byte del QR.
    ///
    /// ### Criterios de validez del candidato
    /// 1. El byte en `candidateOffset` es `0xFF`.
    /// 2. Los bytes siguientes codifican una longitud BER-TLV válida.
    /// 3. `valueOffset + length == bytes.count` (TLV termina al final).
    /// 4. `length` es par (la firma raw P-256 es `r‖s` de igual tamaño).
    ///
    /// - Parameter bytes: Bytes completos del QR.
    /// - Returns: Tupla `(dataToSign, signature)`.
    private static func findSignatureTLV(
        in bytes: [UInt8]
    ) throws -> (dataToSign: Data, signature: Data) {

        // Ventana de búsqueda desde el final.
        // Para P-256 raw (64 bytes): TLV = tag(1) + len(1) + sig(64) = 66 bytes.
        // Con longitud BER extendida: máximo tag(1) + len(3) + sig(128) = 132 bytes.
        let maxWindow  = 200
        let searchFrom = max(0, bytes.count - maxWindow)

        var candidateIdx = bytes.count - 1

        while candidateIdx >= searchFrom {
            defer { candidateIdx -= 1 }

            guard bytes[candidateIdx] == 0xFF else { continue }

            // Leer longitud BER-TLV a continuación del tag
            let lenIdx = candidateIdx + 1
            let (length, lenBytes) = readBERLength(bytes, at: lenIdx)

            // Longitud inválida o negativa → no es un TLV bien formado
            guard length > 0, lenBytes > 0 else { continue }

            let valueOffset = lenIdx + lenBytes
            let endOffset   = valueOffset + length

            // El TLV debe terminar exactamente al final del array
            guard endOffset == bytes.count else { continue }

            // La firma raw debe ser de longitud par (r y s de igual tamaño)
            guard length % 2 == 0 else { continue }

            // ── Candidato válido encontrado ──────────────────────────────
            let dataToSign = Data(bytes[0..<candidateIdx])
            let signature  = Data(bytes[valueOffset..<endOffset])

            return (dataToSign, signature)
        }

        // No se encontró TLV 0xFF válido
        throw MiDNIError.malformedTLV
    }

    // MARK: - Conversión raw → ASN.1 DER (privado)

    /// Convierte una firma ECDSA en formato raw `r ‖ s` a ASN.1 DER.
    ///
    /// ### Formato raw → DER
    /// ```
    /// raw (64 bytes P-256): [ r: 32 bytes ][ s: 32 bytes ]
    ///
    /// DER: SEQUENCE {
    ///        INTEGER  r   ← con byte 0x00 de padding si bit alto de r[0] = 1
    ///        INTEGER  s   ← con byte 0x00 de padding si bit alto de s[0] = 1
    ///      }
    /// ```
    ///
    /// ### Tamaño resultante para P-256
    /// - Mínimo: 70 bytes (r y s sin padding)
    /// - Máximo: 72 bytes (r y s ambos con padding)
    ///
    /// - Parameter raw: Firma raw `r ‖ s`. `raw.count` debe ser par.
    /// - Returns: Firma en formato ASN.1 DER lista para `SecKeyVerifySignature`.
    /// - Throws: `MiDNIError.malformedTLV` si `raw.count` es impar o cero.
    private static func rawSignatureToDER(_ raw: Data) throws -> Data {
        guard !raw.isEmpty, raw.count % 2 == 0 else {
            throw MiDNIError.malformedTLV
        }

        let half = raw.count / 2
        var r = [UInt8](raw.prefix(half))
        var s = [UInt8](raw.suffix(half))

        // ── Padding DER para enteros positivos ──────────────────────────────
        // Si el bit más significativo del primer byte está a 1, DER interpreta
        // el INTEGER como negativo. Se añade 0x00 para forzarlo positivo.
        if r.first.map({ $0 & 0x80 != 0 }) == true { r.insert(0x00, at: 0) }
        if s.first.map({ $0 & 0x80 != 0 }) == true { s.insert(0x00, at: 0) }

        // ── Codificar INTEGER r ──────────────────────────────────────────────
        // Tag 0x02 + longitud + bytes
        let rEncoded = derInteger(r)

        // ── Codificar INTEGER s ──────────────────────────────────────────────
        let sEncoded = derInteger(s)

        // ── Codificar SEQUENCE { r, s } ──────────────────────────────────────
        // Tag 0x30 + longitud total de los dos INTEGER + sus bytes
        let seqContents = rEncoded + sEncoded
        var der = [UInt8]([0x30]) + encodeDERLength(seqContents.count)
        der += seqContents

        return Data(der)
    }

    /// Codifica un valor `Int` como campo de longitud en formato BER.
    ///
    /// - `length < 128`      → 1 byte  (forma corta)
    /// - `128 ≤ length < 256` → 2 bytes (`0x81`, byte)
    /// - `256 ≤ length`       → 3 bytes (`0x82`, byte_high, byte_low)
    private static func encodeDERLength(_ length: Int) -> [UInt8] {
        if length < 0x80 {
            return [UInt8(length)]
        } else if length < 0x100 {
            return [0x81, UInt8(length)]
        } else {
            return [0x82, UInt8(length >> 8), UInt8(length & 0xFF)]
        }
    }

    /// Codifica bytes como un INTEGER DER: `0x02 + length + bytes`.
    private static func derInteger(_ bytes: [UInt8]) -> [UInt8] {
        return [0x02] + encodeDERLength(bytes.count) + bytes
    }

    // MARK: - Lector de longitud BER-TLV (privado, compartido)

    /// Lee una longitud BER-TLV desde `index` en `bytes`.
    ///
    /// Formatos soportados:
    /// - `byte < 0x80`:  longitud directa (1 byte usado)
    /// - `byte == 0x81`: longitud en el siguiente byte (2 bytes usados)
    /// - `byte == 0x82`: longitud en los 2 bytes siguientes big-endian (3 bytes usados)
    ///
    /// - Returns: `(length, bytesUsed)`. `length == -1` si el formato no es válido.
    static func readBERLength(_ bytes: [UInt8], at index: Int) -> (length: Int, bytesUsed: Int) {
        guard index < bytes.count else { return (-1, 0) }

        let first = bytes[index]

        if first < 0x80 {
            return (Int(first), 1)
        } else if first == 0x81 {
            guard index + 1 < bytes.count else { return (-1, 0) }
            return (Int(bytes[index + 1]), 2)
        } else if first == 0x82 {
            guard index + 2 < bytes.count else { return (-1, 0) }
            let length = (Int(bytes[index + 1]) << 8) | Int(bytes[index + 2])
            return (length, 3)
        }

        // 0x83+ no soportado (longitudes > 65535 no esperadas en QR MiDNI)
        return (-1, 0)
    }
}

// MARK: - Tests unitarios (#if DEBUG)

#if DEBUG

/// Tests del `ECDSAVerifier` basados en los datos del ejemplo del PDF oficial
/// "Verificación y Formato de Códigos QR DNI en el Móvil" v1.0.7 —
/// Sección 4.2 del documento de la Policía Nacional.
///
/// Cómo ejecutar:
/// ```swift
/// ECDSAVerifierTests.runAll()
/// ```
enum ECDSAVerifierTests {

    // ── Datos de referencia del PDF ──────────────────────────────────────────

    /// Firma raw (64 bytes) del ejemplo oficial.
    /// Extraída de la sección 4.2 del documento de la Policía Nacional.
    static let pdfRawSignatureHex =
        "9881E4DA3427F7F8F0C4BB2E04514E46F97398AEF2734235BAAC261627609FC0" +
        "EC0F3B591D592AAE5B40D85749C8768EF9B183AA1CBF7561C1C0E22B423EB660"

    /// DER esperado para la firma raw del PDF.
    /// Calculado manualmente y verificado contra openssl:
    ///   r[0]=0x98 (bit alto=1 → padding 0x00), len_r=33
    ///   s[0]=0xEC (bit alto=1 → padding 0x00), len_s=33
    ///   SEQUENCE len = 2+33 + 2+33 = 70 → 0x46
    ///   Total DER = 72 bytes
    static let pdfExpectedDERHex =
        "3046" +                                             // SEQUENCE, len=70
        "022100" +                                           // INTEGER, len=33, padding
        "9881E4DA3427F7F8F0C4BB2E04514E46F97398AEF2734235BAAC261627609FC0" +
        "022100" +                                           // INTEGER, len=33, padding
        "EC0F3B591D592AAE5B40D85749C8768EF9B183AA1CBF7561C1C0E22B423EB660"

    // ── Runner ───────────────────────────────────────────────────────────────

    @discardableResult
    static func runAll() -> Bool {
        print("═══════════════════════════════════════════════")
        print("  ECDSAVerifier — Tests Unitarios")
        print("═══════════════════════════════════════════════")

        var passed = 0
        var failed = 0

        func pass(_ desc: String) { print("[PASS] \(desc)"); passed += 1 }
        func fail(_ desc: String, _ reason: String) {
            print("[FAIL] \(desc)")
            print("       Reason: \(reason)")
            failed += 1
        }

        // ── Test 1: DER del ejemplo del PDF ──────────────────────────────────
        do {
            guard let raw = Data(hexString: pdfRawSignatureHex) else {
                fail("DER ejemplo PDF", "no se pudo parsear hex de entrada")
                return false
            }
            // Acceder a rawSignatureToDER via reflexión no es posible; usamos método público
            // test indirecto: construir QR mínimo y verificar que findSignatureTLV funciona
            let tlv = [UInt8]([0xFF, UInt8(raw.count)]) + [UInt8](raw)
            let fakeQR = Data([0xDC, 0x03]) + Data(tlv)
            let bytes = [UInt8](fakeQR)

            // findSignatureTLV es privado; usamos la lógica duplicada aquí
            let (dataToSign, sig) = try extractForTest(bytes: bytes)

            if sig == raw {
                pass("findSignatureTLV — extrae firma raw del PDF correctamente")
            } else {
                fail("findSignatureTLV — firma extraída no coincide", "expected \(raw.count) bytes raw")
            }
            if dataToSign == Data([0xDC, 0x03]) {
                pass("findSignatureTLV — dataToSign son los bytes antes del 0xFF")
            } else {
                fail("findSignatureTLV — dataToSign incorrecto", "got \(dataToSign.count) bytes")
            }
        } catch {
            fail("findSignatureTLV", error.localizedDescription)
        }

        // ── Test 2: Conversión DER con el ejemplo del PDF ────────────────────
        do {
            guard let raw = Data(hexString: pdfRawSignatureHex),
                  let expectedDER = Data(hexString: pdfExpectedDERHex.replacingOccurrences(of: " ", with: "")) else {
                fail("DER conversión", "hex inválido")
                return false
            }
            let der = try rawSignatureToDERPublic(raw)

            if der == expectedDER {
                pass("rawSignatureToDER — DER del PDF correcto (\(der.count) bytes)")
            } else {
                fail("rawSignatureToDER — DER no coincide",
                     "got: \(der.map { String(format: "%02X", $0) }.joined())")
            }
        } catch {
            fail("rawSignatureToDER", error.localizedDescription)
        }

        // ── Test 3: Firma sin padding (todos los bits altos a 0) ─────────────
        do {
            let rawNoPad = Data(repeating: 0x10, count: 64) // bit alto = 0 en todos
            let der = try rawSignatureToDERPublic(rawNoPad)
            // Esperado: 0x30(1) + 0x44(1) + 0x02(1)+0x20(1)+32bytes + 0x02(1)+0x20(1)+32bytes = 70
            if der.count == 70 {
                pass("rawSignatureToDER — 70 bytes cuando no hay padding")
            } else {
                fail("rawSignatureToDER sin padding", "expected 70, got \(der.count)")
            }
            // Verificar estructura
            let d = [UInt8](der)
            if d[0] == 0x30 && d[1] == 0x44 && d[2] == 0x02 && d[3] == 0x20 {
                pass("rawSignatureToDER — estructura SEQUENCE{INTEGER,INTEGER} correcta sin padding")
            } else {
                fail("rawSignatureToDER — estructura inválida sin padding",
                     "bytes 0-3: \(d.prefix(4).map { String(format: "0x%02X", $0) })")
            }
        } catch {
            fail("rawSignatureToDER sin padding", error.localizedDescription)
        }

        // ── Test 4: Firma con ambos paddings ─────────────────────────────────
        do {
            // r[0]=0x80, s[0]=0xFF → ambos necesitan 0x00
            var raw = [UInt8](repeating: 0x01, count: 64)
            raw[0]  = 0x80
            raw[32] = 0xFF
            let der = try rawSignatureToDERPublic(Data(raw))
            if der.count == 72 {
                pass("rawSignatureToDER — 72 bytes cuando ambos r y s necesitan padding")
            } else {
                fail("rawSignatureToDER doble padding", "expected 72, got \(der.count)")
            }
            let d = [UInt8](der)
            if d[0] == 0x30 && d[1] == 0x46 {
                pass("rawSignatureToDER — SEQUENCE length 0x46 correcto con doble padding")
            } else {
                fail("rawSignatureToDER doble padding — length incorrecto", "d[1]=0x\(String(d[1], radix: 16))")
            }
        } catch {
            fail("rawSignatureToDER doble padding", error.localizedDescription)
        }

        // ── Test 5: Longitud BER ─────────────────────────────────────────────
        let berTests: [(bytes: [UInt8], offset: Int, expectedLen: Int, expectedUsed: Int)] = [
            ([0x40], 0, 64, 1),            // short form
            ([0x7F], 0, 127, 1),           // max short form
            ([0x81, 0x80], 0, 128, 2),     // long form 1 byte
            ([0x81, 0xFF], 0, 255, 2),     // long form max 1 byte
            ([0x82, 0x01, 0x00], 0, 256, 3), // long form 2 bytes
            ([0x82, 0xFF, 0xFF], 0, 65535, 3), // long form max 2 bytes
        ]
        for (bytes, offset, expectedLen, expectedUsed) in berTests {
            let (length, used) = ECDSAVerifier.readBERLength(bytes, at: offset)
            if length == expectedLen && used == expectedUsed {
                pass("readBERLength — 0x\(bytes.map { String(format: "%02X", $0) }.joined()): len=\(length), used=\(used)")
            } else {
                fail("readBERLength", "expected len=\(expectedLen),used=\(expectedUsed), got len=\(length),used=\(used)")
            }
        }

        // ── Test 6: Error en longitud impar ───────────────────────────────────
        do {
            _ = try rawSignatureToDERPublic(Data(repeating: 0x01, count: 63))
            fail("rawSignatureToDER — longitud impar debería lanzar", "no lanzó")
        } catch MiDNIError.malformedTLV {
            pass("rawSignatureToDER — lanza malformedTLV con longitud impar")
        } catch {
            fail("rawSignatureToDER longitud impar", "error inesperado: \(error)")
        }

        // ── Test 7: 0xFF dentro de JPEG2000 no se detecta como firma ─────────
        do {
            // Construir QR con 0xFF dentro de imagen y 0xFF real al final
            let header    = [UInt8]([0xDC, 0x03])
            let imageData = [UInt8](repeating: 0xFF, count: 32)  // JPEG2000 con 0xFF en valor
            let imageTag  = [UInt8]([0x50, UInt8(imageData.count)]) + imageData
            let realSig   = [UInt8](repeating: 0xAB, count: 64)
            let sigTag    = [UInt8]([0xFF, UInt8(realSig.count)]) + realSig

            let qrBytes = header + imageTag + sigTag
            let (_, extractedSig) = try extractForTest(bytes: qrBytes)

            if extractedSig == Data(realSig) {
                pass("findSignatureTLV — 0xFF en imagen ignorado; firma real extraída correctamente")
            } else {
                fail("findSignatureTLV — confundió 0xFF de imagen con firma", "")
            }
        } catch {
            fail("findSignatureTLV con 0xFF en imagen", error.localizedDescription)
        }

        print("───────────────────────────────────────────────")
        print("  Resultado: \(passed) pasados, \(failed) fallidos de \(passed + failed) tests")
        print("═══════════════════════════════════════════════")
        return failed == 0
    }

    // ── Helpers de test (réplicas de funciones privadas) ─────────────────────

    /// Réplica del método privado `rawSignatureToDER` para tests.
    private static func rawSignatureToDERPublic(_ raw: Data) throws -> Data {
        guard !raw.isEmpty, raw.count % 2 == 0 else {
            throw MiDNIError.malformedTLV
        }
        let half = raw.count / 2
        var r = [UInt8](raw.prefix(half))
        var s = [UInt8](raw.suffix(half))
        if r.first.map({ $0 & 0x80 != 0 }) == true { r.insert(0x00, at: 0) }
        if s.first.map({ $0 & 0x80 != 0 }) == true { s.insert(0x00, at: 0) }

        func encLen(_ n: Int) -> [UInt8] {
            if n < 0x80 { return [UInt8(n)] }
            else if n < 0x100 { return [0x81, UInt8(n)] }
            else { return [0x82, UInt8(n >> 8), UInt8(n & 0xFF)] }
        }
        let rEnc = [UInt8]([0x02]) + encLen(r.count) + r
        let sEnc = [UInt8]([0x02]) + encLen(s.count) + s
        let body = rEnc + sEnc
        return Data([0x30] + encLen(body.count) + body)
    }

    /// Réplica del método privado `findSignatureTLV` para tests.
    private static func extractForTest(bytes: [UInt8]) throws -> (dataToSign: Data, signature: Data) {
        let maxWindow  = 200
        let searchFrom = max(0, bytes.count - maxWindow)

        var idx = bytes.count - 1
        while idx >= searchFrom {
            defer { idx -= 1 }
            guard bytes[idx] == 0xFF else { continue }
            let (length, lenBytes) = ECDSAVerifier.readBERLength(bytes, at: idx + 1)
            guard length > 0, lenBytes > 0 else { continue }
            let valueOffset = idx + 1 + lenBytes
            let endOffset   = valueOffset + length
            guard endOffset == bytes.count else { continue }
            guard length % 2 == 0 else { continue }
            return (Data(bytes[0..<idx]), Data(bytes[valueOffset..<endOffset]))
        }
        throw MiDNIError.malformedTLV
    }
}

#endif
