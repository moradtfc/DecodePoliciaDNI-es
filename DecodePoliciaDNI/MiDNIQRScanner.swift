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

        return parseMiDNIStructure(data)
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

        // 1. Magic Constant
        let magicConstant = data[index]
        index += 1

        // 2. Version
        let version = data[index]
        index += 1

        guard magicConstant == 0xDC, version == 0x03 else {
            print("❌ QR no válido: Magic=\(String(format: "%02x", magicConstant)), Version=\(String(format: "%02x", version))")
            return nil
        }

        // 3. País (C40 encoded, 2 bytes)
        let countryData = data[index..<index+2]
        let country = decodeC40(countryData) ?? "??"
        index += 2

        // 4. Identificador del firmante (variable)
        // Primero 4 chars en C40 (4 bytes) para obtener "ESPN"
        let signerIdData = data[index..<index+4]
        let signerIdPrefix = decodeC40(signerIdData) ?? "????"
        index += 4

        // Los últimos 2 dígitos indican la longitud de la referencia del certificado
        let certRefLengthStr = String(signerIdPrefix.suffix(2))
        let certRefLength = Int(certRefLengthStr, radix: 16) ?? 32

        // Calcular bytes necesarios para C40
        let certRefC40Bytes = ((certRefLength + 2) / 3) * 2
        let certRefData = data[index..<index+certRefC40Bytes]
        let certificateReference = decodeC40(certRefData) ?? ""
        index += certRefC40Bytes

        // 5. Fecha de emisión (3 bytes)
        let documentIssueDate = decodeICAODate(data[index..<index+3])
        index += 3

        // 6. Fecha de firma (3 bytes)
        let signatureDate = decodeICAODate(data[index..<index+3])
        index += 3

        // 7. Tipo de QR (1 byte)
        let qrTypeRaw = data[index]
        let qrType = MiDNIData.QRType(rawValue: qrTypeRaw) ?? .simple
        index += 1

        // 8. Categoría de documento (1 byte)
        let documentCategory = data[index]
        index += 1

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

        return miDNI
    }

    // MARK: - TLV Parsing

    private func parseTLVFields(_ data: Data, startIndex: Int, miDNI: inout MiDNIData) {
        var index = startIndex

        while index < data.count {
            let tag = data[index]
            index += 1

            // Firma: último campo
            if tag == 0xFF {
                print("📝 Firma encontrada en posición \(index-1)")
                break
            }

            // Leer longitud
            var length = 0
            let firstLengthByte = data[index]
            index += 1

            if firstLengthByte & 0x80 == 0 {
                // Longitud corta (1 byte)
                length = Int(firstLengthByte)
            } else {
                // Longitud larga
                let numLengthBytes = Int(firstLengthByte & 0x7F)
                for _ in 0..<numLengthBytes {
                    length = (length << 8) | Int(data[index])
                    index += 1
                }
            }

            guard index + length <= data.count else {
                print("⚠️ Longitud inválida en tag \(String(format: "0x%02x", tag))")
                break
            }

            let value = data[index..<index+length]
            index += length

            // Procesar según el tag
            switch tag {
            case 0x40: // Número de DNI
                miDNI.dniNumber = String(data: value, encoding: .ascii)
                print("🆔 DNI: \(miDNI.dniNumber ?? "N/A")")

            case 0x42: // Fecha de nacimiento
                miDNI.birthDate = String(data: value, encoding: .ascii)
                print("🎂 Fecha nacimiento: \(miDNI.birthDate ?? "N/A")")

            case 0x44: // Nombre
                miDNI.name = String(data: value, encoding: .utf8)
                print("👤 Nombre: \(miDNI.name ?? "N/A")")

            case 0x46: // Apellidos
                miDNI.surnames = String(data: value, encoding: .utf8)
                print("👥 Apellidos: \(miDNI.surnames ?? "N/A")")

            case 0x48: // Sexo
                miDNI.sex = String(data: value, encoding: .ascii)
                print("⚥ Sexo: \(miDNI.sex ?? "N/A")")

            case 0x4C: // Fecha caducidad documento
                miDNI.documentExpiryDate = String(data: value, encoding: .ascii)
                print("📅 Caducidad doc: \(miDNI.documentExpiryDate ?? "N/A")")

            case 0x50: // Imagen miniatura
                miDNI.photo = value
                print("🖼️ Foto: \(value.count) bytes (JPEG2000)")

            case 0x70: // Mayor de edad
                miDNI.isAdult = value.first == 0x01
                print("🔞 Mayor de edad: \(miDNI.isAdult == true ? "SÍ" : "NO")")

            case 0x80: // Caducidad de los datos del QR
                let dateString = String(data: value, encoding: .ascii) ?? ""
                miDNI.dataExpiryDate = parseDataExpiryDate(dateString)
                print("⏱️ Caducidad datos: \(dateString)")

            default:
                print("ℹ️ Tag desconocido: 0x\(String(format: "%02x", tag)) (\(length) bytes)")
            }
        }
    }

    // MARK: - Helper Functions

    private func decodeC40(_ data: Data) -> String? {
        // Implementación simplificada de C40
        // Para producción, necesitarías la implementación completa según ICAO 9303
        var result = ""
        var bits = 0
        var bitCount = 0

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
        guard data.count == 3 else { return nil }

        let days = (Int(data[0]) << 8) | Int(data[1])
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
