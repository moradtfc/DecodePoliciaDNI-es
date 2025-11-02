//
//  MiDNIQRScanner.swift
//  DecodePoliciaDNI
//
//  Created by Jesus Mora on 1/11/25.
//

import AVFoundation
import UIKit

class MiDNIQRScanner: NSObject {

    // MARK: - Data Models

    struct MiDNIData {
        let magicConstant: UInt8
        let version: UInt8
        let country: String
        let signerReference: String
        let documentIssueDate: Date?
        let signatureDate: Date?
        let qrType: QRType
        let documentCategory: UInt8

        // Datos del cuerpo
        var dniNumber: String?
        var birthDate: String?
        var name: String?
        var surnames: String?
        var sex: String?
        var documentExpiryDate: String?
        var photo: Data?
        var isAdult: Bool?
        var dataExpiryDate: Date?

        // Dump hexadecimal completo (sin espacios, sin offsets, sin guiones)
        var rawHexDump: String?

        var isValid: Bool {
            return magicConstant == 0xDC && version == 0x03
        }

        enum QRType: UInt8 {
            case age = 0x09
            case simple = 0x07
            case complete = 0x08

            var description: String {
                switch self {
                case .age: return "Verificación de Edad"
                case .simple: return "DNI Simple"
                case .complete: return "DNI Completo"
                }
            }
        }
    }

    // MARK: - QR Decoding

    /// Decodifica datos binarios directamente (método preferido)
    func decodeQRDataFromBytes(_ data: Data) -> MiDNIData? {
        print("🔍 Intentando decodificar \(data.count) bytes de datos binarios")

        guard data.count > 38 else {
            print("❌ Datos insuficientes: \(data.count) bytes (mínimo 38)")
            return nil
        }

        // Generar el dump hexadecimal completo (sin espacios, sin offsets, sin guiones)
        let hexDump = data.map { String(format: "%02x", $0) }.joined()
        print("💾 Dump hexadecimal completo guardado: \(hexDump.count) caracteres")

        var miDNI = parseMiDNIStructure(data)

        // Guardar el dump hexadecimal en la estructura
        miDNI?.rawHexDump = hexDump

        return miDNI
    }

    /// Decodifica desde string (para retrocompatibilidad)
    func decodeQRData(_ stringValue: String) -> MiDNIData? {
        var rawData: Data?

        // Método 1: Base64
        if let decoded = Data(base64Encoded: stringValue) {
            rawData = decoded
            print("✅ Decodificado como Base64")
        }
        // Método 2: ISO Latin 1 (binario directo)
        else if let decoded = stringValue.data(using: .isoLatin1) {
            rawData = decoded
            print("✅ Decodificado como ISO Latin 1")
        }

        guard let data = rawData, data.count > 38 else {
            print("❌ Datos insuficientes")
            return nil
        }

        return parseMiDNIStructure(data)
    }

    private func parseMiDNIStructure(_ data: Data) -> MiDNIData? {
        var index = 0

        print("\n" + String(repeating: "=", count: 80))
        print("📖 DECODIFICACIÓN SEGÚN ESPECIFICACIÓN ICAO 9303")
        print(String(repeating: "=", count: 80))
        print("📊 Tamaño total de datos: \(data.count) bytes")

        // 1. Magic Constant
        guard index < data.count else {
            print("❌ No hay suficientes datos para leer Magic Constant")
            return nil
        }
        let magicConstant = data[index]
        print("\n[Byte \(index)] Magic Constant: 0x\(String(format: "%02x", magicConstant)) (esperado: 0xDC)")
        index += 1

        // 2. Version
        guard index < data.count else {
            print("❌ No hay suficientes datos para leer Version")
            return nil
        }
        let version = data[index]
        print("[Byte \(index)] Version: 0x\(String(format: "%02x", version)) (esperado: 0x03)")
        index += 1

        guard magicConstant == 0xDC, version == 0x03 else {
            print("❌ QR no válido: Magic=\(String(format: "%02x", magicConstant)), Version=\(String(format: "%02x", version))")
            return nil
        }

        // 3. País (C40 encoded, 2 bytes)
        guard index + 2 <= data.count else {
            print("❌ No hay suficientes datos para leer País (necesita \(index + 2) bytes, disponible: \(data.count))")
            return nil
        }
        let countryData = data[index..<index+2]
        let countryHex = countryData.map { String(format: "%02x", $0) }.joined(separator: " ")
        let country = decodeC40(countryData) ?? "??"
        print("[Bytes \(index)-\(index+1)] País (C40): \(countryHex) → \"\(country)\"")
        index += 2

        // 4. Identificador del firmante (variable)
        guard index + 4 <= data.count else {
            print("❌ No hay suficientes datos para leer Signer ID (necesita \(index + 4) bytes, disponible: \(data.count))")
            return nil
        }
        let signerIdData = data[index..<index+4]
        let signerIdHex = signerIdData.map { String(format: "%02x", $0) }.joined(separator: " ")
        let signerIdPrefix = decodeC40(signerIdData) ?? "????"
        print("[Bytes \(index)-\(index+3)] Signer ID Prefix (C40): \(signerIdHex) → \"\(signerIdPrefix)\"")
        index += 4

        // Los últimos 2 dígitos indican la longitud de la referencia del certificado
        let certRefLengthStr = String(signerIdPrefix.suffix(2))
        let certRefLength = Int(certRefLengthStr, radix: 16) ?? 32
        print("   ↳ Longitud referencia certificado: \(certRefLength) bytes (0x\(certRefLengthStr))")

        // Calcular bytes necesarios para C40
        let certRefC40Bytes = ((certRefLength + 2) / 3) * 2
        guard index + certRefC40Bytes <= data.count else {
            print("❌ No hay suficientes datos para leer Certificado (necesita \(index + certRefC40Bytes) bytes, disponible: \(data.count))")
            return nil
        }
        let certRefData = data[index..<index+certRefC40Bytes]
        let certRefHex = certRefData.map { String(format: "%02x", $0) }.joined(separator: " ")
        let certificateReference = decodeC40(certRefData) ?? ""
        print("[Bytes \(index)-\(index+certRefC40Bytes-1)] Certificado (C40, \(certRefC40Bytes) bytes):")
        print("   Hex: \(certRefHex)")
        print("   Decodificado: \"\(certificateReference)\"")
        index += certRefC40Bytes

        // 5. Fecha de emisión (3 bytes)
        guard index + 3 <= data.count else {
            print("❌ No hay suficientes datos para leer Fecha emisión (necesita \(index + 3) bytes, disponible: \(data.count))")
            return nil
        }
        let issueData = data[index..<index+3]
        let issueHex = issueData.map { String(format: "%02x", $0) }.joined(separator: " ")
        let documentIssueDate = decodeICAODate(issueData)
        print("[Bytes \(index)-\(index+2)] Fecha emisión (ICAO): \(issueHex) → \(documentIssueDate?.description ?? "N/A")")
        index += 3

        // 6. Fecha de firma (3 bytes)
        guard index + 3 <= data.count else {
            print("❌ No hay suficientes datos para leer Fecha firma (necesita \(index + 3) bytes, disponible: \(data.count))")
            return nil
        }
        let signData = data[index..<index+3]
        let signHex = signData.map { String(format: "%02x", $0) }.joined(separator: " ")
        let signatureDate = decodeICAODate(signData)
        print("[Bytes \(index)-\(index+2)] Fecha firma (ICAO): \(signHex) → \(signatureDate?.description ?? "N/A")")
        index += 3

        // 7. Tipo de QR (1 byte)
        guard index < data.count else {
            print("❌ No hay suficientes datos para leer Tipo QR")
            return nil
        }
        let qrTypeRaw = data[index]
        let qrType = MiDNIData.QRType(rawValue: qrTypeRaw) ?? .simple
        print("[Byte \(index)] Tipo QR: 0x\(String(format: "%02x", qrTypeRaw)) → \(qrType.description)")
        index += 1

        // 8. Categoría de documento (1 byte)
        guard index < data.count else {
            print("❌ No hay suficientes datos para leer Categoría documento")
            return nil
        }
        let documentCategory = data[index]
        print("[Byte \(index)] Categoría documento: 0x\(String(format: "%02x", documentCategory))")
        index += 1

        print("\n" + String(repeating: "-", count: 80))
        print("📦 INICIO DE CAMPOS TLV (Tag-Length-Value)")
        print(String(repeating: "-", count: 80))

        var miDNI = MiDNIData(
            magicConstant: magicConstant,
            version: version,
            country: country,
            signerReference: certificateReference,
            documentIssueDate: documentIssueDate,
            signatureDate: signatureDate,
            qrType: qrType,
            documentCategory: documentCategory
        )

        // 9. Parsear TLV (cuerpo del mensaje)
        parseTLVFields(data, startIndex: index, miDNI: &miDNI)

        print(String(repeating: "=", count: 80) + "\n")

        return miDNI
    }

    // MARK: - TLV Parsing

    private func parseTLVFields(_ data: Data, startIndex: Int, miDNI: inout MiDNIData) {
        var index = startIndex
        var fieldNumber = 1

        while index < data.count {
            let tagOffset = index
            let tag = data[index]
            index += 1

            // Firma: último campo
            if tag == 0xFF {
                print("\n[Byte \(tagOffset)] Tag 0xFF: FIRMA (fin de campos TLV)")
                let remainingBytes = data.count - tagOffset
                print("   Bytes restantes (firma + padding): \(remainingBytes)")
                break
            }

            // Leer longitud
            var length = 0
            let lengthOffset = index
            let firstLengthByte = data[index]
            index += 1

            var lengthBytes = 1
            if firstLengthByte & 0x80 == 0 {
                // Longitud corta (1 byte)
                length = Int(firstLengthByte)
            } else {
                // Longitud larga
                let numLengthBytes = Int(firstLengthByte & 0x7F)
                lengthBytes = 1 + numLengthBytes
                for _ in 0..<numLengthBytes {
                    length = (length << 8) | Int(data[index])
                    index += 1
                }
            }

            guard index + length <= data.count else {
                print("⚠️ [Byte \(tagOffset)] Tag 0x\(String(format: "%02x", tag)): Longitud inválida (\(length) bytes excede datos disponibles)")
                break
            }

            let valueOffset = index
            let value = data[index..<index+length]
            let valueHex = value.prefix(min(20, value.count)).map { String(format: "%02x", $0) }.joined(separator: " ")
            let valueHexSuffix = value.count > 20 ? "..." : ""

            index += length

            // Procesar según el tag
            print("\n[Byte \(tagOffset)] Campo #\(fieldNumber) - Tag 0x\(String(format: "%02x", tag)):")
            print("   Length: \(length) bytes (offset \(lengthOffset), \(lengthBytes) byte(s))")
            print("   Value offset: \(valueOffset)")
            print("   Value hex: \(valueHex)\(valueHexSuffix)")

            switch tag {
            case 0x40: // Número de DNI
                miDNI.dniNumber = String(data: value, encoding: .ascii)
                print("   → 🆔 DNI: \(miDNI.dniNumber ?? "N/A")")

            case 0x42: // Fecha de nacimiento
                miDNI.birthDate = String(data: value, encoding: .ascii)
                print("   → 🎂 Fecha nacimiento: \(miDNI.birthDate ?? "N/A")")

            case 0x44: // Nombre
                miDNI.name = String(data: value, encoding: .utf8)
                print("   → 👤 Nombre: \(miDNI.name ?? "N/A")")

            case 0x46: // Apellidos
                miDNI.surnames = String(data: value, encoding: .utf8)
                print("   → 👥 Apellidos: \(miDNI.surnames ?? "N/A")")

            case 0x48: // Sexo
                miDNI.sex = String(data: value, encoding: .ascii)
                print("   → ⚥ Sexo: \(miDNI.sex ?? "N/A")")

            case 0x4C: // Fecha caducidad documento
                miDNI.documentExpiryDate = String(data: value, encoding: .ascii)
                print("   → 📅 Caducidad doc: \(miDNI.documentExpiryDate ?? "N/A")")

            case 0x50: // Imagen miniatura
                miDNI.photo = value
                print("   → 🖼️ Foto: \(value.count) bytes (JPEG2000)")
                print("      Primeros bytes: \(value.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")

            case 0x70: // Mayor de edad
                miDNI.isAdult = value.first == 0x01
                print("   → 🔞 Mayor de edad: \(miDNI.isAdult == true ? "SÍ (0x01)" : "NO (0x00)")")

            case 0x80: // Caducidad de los datos del QR
                let dateString = String(data: value, encoding: .ascii) ?? ""
                miDNI.dataExpiryDate = parseDataExpiryDate(dateString)
                print("   → ⏱️ Caducidad datos: \(dateString)")

            default:
                print("   → ℹ️ Tag desconocido")
                if length < 100 {
                    let fullHex = value.map { String(format: "%02x", $0) }.joined(separator: " ")
                    print("      Valor completo: \(fullHex)")
                }
            }

            fieldNumber += 1
        }
    }

    // MARK: - Helper Functions

    private func decodeC40(_ data: Data) -> String? {
        // Implementación simplificada de C40
        // Para producción, necesitarías la implementación completa según ICAO 9303

        guard !data.isEmpty else {
            print("⚠️ decodeC40: data vacío")
            return nil
        }

        var result = ""
        var bits = 0
        var bitCount = 0

        // Iterar sobre los bytes (funciona correctamente con slices)
        for byte in data {
            bits = (bits << 8) | Int(byte)
            bitCount += 8

            while bitCount >= 16 {
                bitCount -= 16
                let value = (bits >> bitCount) & 0xFFFF

                let c1 = (value / 1600)
                let c2 = (value / 40) % 40
                let c3 = value % 40

                for c in [c1, c2, c3] {
                    if c == 0 { continue }
                    if c <= 3 { continue }
                    if c >= 4 && c <= 13 { result.append(Character(UnicodeScalar(c - 4 + 48)!)) }
                    else if c >= 14 && c <= 39 { result.append(Character(UnicodeScalar(c - 14 + 65)!)) }
                }

                bits &= (1 << bitCount) - 1
            }
        }

        return result
    }

    private func decodeICAODate(_ data: Data) -> Date? {
        guard data.count >= 3 else {
            print("⚠️ decodeICAODate: datos insuficientes (\(data.count) bytes, necesita 3)")
            return nil
        }

        // Usar startIndex para acceder correctamente a slices de Data
        let idx0 = data.startIndex
        let idx1 = data.index(after: idx0)
        let idx2 = data.index(after: idx1)

        guard idx2 < data.endIndex else {
            print("⚠️ decodeICAODate: índices fuera de rango")
            return nil
        }

        let days = (Int(data[idx0]) << 8) | Int(data[idx1])
        let year = days / 365 + 2000
        let dayOfYear = days % 365

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.day = dayOfYear

        return calendar.date(from: components)
    }

    private func parseDataExpiryDate(_ dateString: String) -> Date? {
        // Formato: "17-04-2029 11:28:20"
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: dateString)
    }

    // MARK: - Print Summary

    func printSummary(_ miDNI: MiDNIData) {
        print("\n" + String(repeating: "=", count: 50))
        print("📱 RESUMEN DEL QR DE miDNI")
        print(String(repeating: "=", count: 50))

        print("\n✅ Validez: \(miDNI.isValid ? "VÁLIDO" : "INVÁLIDO")")
        print("🏳️  País: \(miDNI.country)")
        print("📋 Tipo: \(miDNI.qrType.description)")

        if let dni = miDNI.dniNumber {
            print("\n🆔 DNI: \(dni)")
        }

        if let name = miDNI.name {
            print("👤 Nombre: \(name)")
        }

        if let surnames = miDNI.surnames {
            print("👥 Apellidos: \(surnames)")
        }

        if let birthDate = miDNI.birthDate {
            print("🎂 Fecha nacimiento: \(birthDate)")
        }

        if let sex = miDNI.sex {
            print("⚥ Sexo: \(sex)")
        }

        if let isAdult = miDNI.isAdult {
            print("🔞 Mayor de edad: \(isAdult ? "SÍ ✅" : "NO ❌")")
        }

        if let expiryDate = miDNI.dataExpiryDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            formatter.timeZone = TimeZone(identifier: "UTC")
            print("⏱️  Datos válidos hasta: \(formatter.string(from: expiryDate))")

            let isExpired = expiryDate < Date()
            print("   Estado: \(isExpired ? "❌ CADUCADO" : "✅ VIGENTE")")
        }

        if let photo = miDNI.photo {
            print("🖼️  Foto: \(photo.count) bytes")
        }

        print("\n🔐 Certificado: \(miDNI.signerReference)")

        if let issueDate = miDNI.documentIssueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            print("📅 Emisión: \(formatter.string(from: issueDate))")
        }

        if let hexDump = miDNI.rawHexDump {
            print("\n💾 DUMP HEXADECIMAL COMPLETO (sin espacios, sin guiones):")
            print("   Longitud: \(hexDump.count) caracteres hex (\(hexDump.count / 2) bytes)")
            print("   Contenido completo:")
            print(hexDump)
        }

        print(String(repeating: "=", count: 50) + "\n")
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension MiDNIQRScanner: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                       didOutput metadataObjects: [AVMetadataObject],
                       from connection: AVCaptureConnection) {

        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }

        print("📲 QR detectado, decodificando...")

        if let miDNI = decodeQRData(stringValue) {
            printSummary(miDNI)

            // Aquí puedes llamar a tu delegate o completion handler
            // onQRDecoded?(miDNI)
        } else {
            print("❌ No se pudo decodificar el QR")
        }
    }
}
