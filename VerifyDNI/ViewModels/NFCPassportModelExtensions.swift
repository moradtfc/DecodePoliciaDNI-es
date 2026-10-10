// NFCPassportModelExtensions.swift
// VerifyDNI
//
// Extensiones sobre NFCPassportModel (SPM oficial v2.3.0) para añadir los
// campos que Santander agregó a su copia embebida:
//
//   • computedIssueDate  — fecha de expedición calculada por reglas de vigencia del DNI
//   • dg13Names          — nombres de pila con tildes (DG13 del chip)
//   • dg13LastNames      — apellidos con tildes en formato "APE1/APE2" (DG13)
//   • dg13Parents        — padres en formato "PADRE/MADRE" (DG13)
//
// Nota: El SPM oficial no expone DG13 como tipo fuerte, pero DataGroup.data
// es `public`, por lo que podemos leer y parsear los bytes sin modificar el SPM.

import Foundation
import NFCPassportReader

@available(iOS 13, *)
extension NFCPassportModel {

    // MARK: - Fecha de expedición

    /// Fecha de expedición del documento.
    ///
    /// **Estrategia (igual que Santander):**
    /// 1. Intenta extraer la fecha real del SOD (Security Object Document) del chip.
    ///    El SOD contiene un UTCTime con la fecha de firma/personalización = fecha de
    ///    expedición real. Santander toma el ÚLTIMO UTCTIME del campo signedData.
    /// 2. Si el SOD no está disponible o no contiene UTCTime válida, calcula
    ///    la fecha restando la vigencia (2/5/10 años según edad) a la caducidad.
    ///
    /// Devuelve la fecha en formato "yyMMdd" para ser procesada por `formatMRZDate()`.
    var computedIssueDate: String? {
        // Prioridad 1: fecha real del SOD
        if let fromSOD = issueDateFromSOD {
            NSLog("[CHIP] 📅 Issue date from SOD: \(fromSOD)")
            return fromSOD
        }
        // Prioridad 2: cálculo por reglas de vigencia
        let fromRules = issueDateByRules
        NSLog("[CHIP] 📅 Issue date by rules: \(fromRules ?? "nil") (SOD not available)")
        return fromRules
    }

    /// Extrae la fecha de expedición del SOD (Security Object Document) del chip.
    ///
    /// Técnica idéntica a Santander `NfcReaderPresenter.readCard()`:
    ///   - Usa `Mirror` para acceder al campo `asn1` privado del SOD
    ///   - Busca patrones UTCTIME en la representación en texto del árbol ASN1
    ///   - Selecciona el ÚLTIMO UTCTIME (siempre es la fecha de expedición del DNI)
    ///   - Valida que la fecha sea razonable (1990 – hoy+1)
    ///
    /// El UTCTIME está en formato `YYMMDDHHmmssZ` (12 dígitos + Z).
    private var issueDateFromSOD: String? {
        guard let sod = dataGroupsRead[.SOD] else { return nil }

        let mirror = Mirror(reflecting: sod)
        for child in mirror.children {
            let valueString = String(describing: child.value)
            guard valueString.contains("UTCTIME") else { continue }

            // Patrón: "UTCTIME YYMMDDHHmmssZ" — extrae todos los que aparezcan
            let pattern = #"UTCTIME\s+([0-9]{12}Z)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsRange = NSRange(valueString.startIndex..<valueString.endIndex, in: valueString)
            let matches = regex.matches(in: valueString, options: [], range: nsRange)

            var allUTCTimes: [String] = []
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let utcRange = Range(match.range(at: 1), in: valueString) else { continue }
                allUTCTimes.append(String(valueString[utcRange]))
            }
            NSLog("[CHIP] 📅 SOD UTCTimes found (\(allUTCTimes.count)): \(allUTCTimes)")

            // El ÚLTIMO UTCTIME siempre es la fecha de expedición (igual que Santander)
            if let lastUTCTime = allUTCTimes.last, let parsed = parseSODUTCTime(lastUTCTime) {
                return parsed
            }
        }
        return nil
    }

    /// Parsea "YYMMDDHHmmssZ" → "yyMMdd" y valida razonabilidad (1990 – año actual+1).
    private func parseSODUTCTime(_ utcString: String) -> String? {
        // Extrae YY, MM, DD de los primeros 6 dígitos
        let pattern = #"^([0-9]{2})([0-9]{2})([0-9]{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(utcString.startIndex..<utcString.endIndex, in: utcString)
        guard let match = regex.firstMatch(in: utcString, options: [], range: nsRange),
              match.numberOfRanges >= 4,
              let yyRange = Range(match.range(at: 1), in: utcString),
              let mmRange = Range(match.range(at: 2), in: utcString),
              let ddRange = Range(match.range(at: 3), in: utcString) else { return nil }

        let yy = String(utcString[yyRange])
        let mm = String(utcString[mmRange])
        let dd = String(utcString[ddRange])

        guard let yyInt = Int(yy), let mmInt = Int(mm), let ddInt = Int(dd),
              mmInt >= 1 && mmInt <= 12 && ddInt >= 1 && ddInt <= 31 else { return nil }

        let fullYear = yyInt < 50 ? 2000 + yyInt : 1900 + yyInt
        let currentYear = Calendar.current.component(.year, from: Date())
        guard fullYear >= 1990 && fullYear <= currentYear + 1 else { return nil }

        return "\(yy)\(mm)\(dd)"   // formato "yyMMdd"
    }

    /// Calcula la fecha de expedición restando la vigencia a la caducidad.
    ///
    /// Reglas del DNI español (Real Decreto 1553/2005):
    ///   - Titular < 5 años  → validez 2 años
    ///   - Titular < 30 años → validez 5 años
    ///   - Titular < 70 años → validez 10 años
    ///   - Titular ≥ 70 años → permanente (nil)
    private var issueDateByRules: String? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyMMdd"

        guard let expiryDate = fmt.date(from: documentExpiryDate),
              let birthDate  = fmt.date(from: dateOfBirth) else { return nil }

        let age = Calendar.current
            .dateComponents([.year], from: birthDate, to: Date()).year ?? 0

        let validityYears: Int
        switch age {
        case ..<5:  validityYears = 2
        case ..<30: validityYears = 5
        case ..<70: validityYears = 10
        default:    return nil   // Permanente — sin fecha de expedición calculable
        }

        guard let issueDate = Calendar.current
            .date(byAdding: .year, value: -validityYears, to: expiryDate) else { return nil }

        let out = DateFormatter()
        out.locale     = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "yyMMdd"
        return out.string(from: issueDate)
    }

    // MARK: - DG13 (datos específicos del DNI/TIE español)

    /// Apellidos desde DG13 — formato "APELLIDO1/APELLIDO2" (con tildes y ñ).
    var dg13LastNames: String?     { dg13Fields()["lastNames"] }
    /// Nombres de pila desde DG13 (con tildes y ñ).
    var dg13Names: String?         { dg13Fields()["names"] }
    /// Nombres de los padres desde DG13 — formato "PADRE/MADRE".
    var dg13Parents: String?       { dg13Fields()["parents"] }
    /// Municipio de nacimiento desde DG13 (índice 11).
    var dg13BirthCity: String?     { dg13Fields()["birthCity"] }
    /// Provincia de nacimiento desde DG13 (índice 12).
    var dg13BirthProvince: String? { dg13Fields()["birthProvince"] }

    // MARK: - Parser interno de DG13

    /// Parsea el bloque TLV de DG13 del DNI español.
    ///
    /// El contenido, una vez eliminados bytes de control, es una cadena
    /// separada por '|'. Índices confirmados en chips reales:
    ///   [2]  → Primer apellido
    ///   [3]  → Segundo apellido
    ///   [4]  → Nombre(s) de pila
    ///   [11] → Municipio de nacimiento
    ///   [12] → Provincia de nacimiento
    ///   [13] → Padres ("PADRE/MADRE")
    ///
    /// NOTA: los índices [14-16] contienen la dirección de residencia actual,
    /// que no tiene relación con el lugar de nacimiento y no se extrae aquí.
    private func dg13Fields() -> [String: String] {
        guard let dg13 = dataGroupsRead[.DG13] else { return [:] }

        let raw  = dg13.data
        let pipe: UInt8 = 124   // '|' = 0x7C

        // Limpiar bytes no-UTF-8 (igual que Santander)
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

        guard let str = String(bytes: valid, encoding: .utf8) else { return [:] }
        let parts = str.split(separator: "|", omittingEmptySubsequences: false)

        // Helper para extraer un campo de forma segura
        func field(_ idx: Int) -> String? {
            guard idx < parts.count else { return nil }
            let s = String(parts[idx]).trimmingCharacters(in: .whitespaces)
            return s.isEmpty ? nil : s
        }

        var result: [String: String] = [:]

        // Apellidos
        let ln1 = field(2) ?? ""
        let ln2 = field(3) ?? ""
        if !ln1.isEmpty || !ln2.isEmpty {
            result["lastNames"] = ln2.isEmpty ? ln1 : "\(ln1)/\(ln2)"
        }

        if let names   = field(4)  { result["names"]        = names   }
        if let bc      = field(11) { result["birthCity"]    = bc      }
        if let bp      = field(12) { result["birthProvince"] = bp     }
        if let parents = field(13) { result["parents"]      = parents }

        return result
    }
}
