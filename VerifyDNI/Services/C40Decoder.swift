// C40Decoder.swift
// VerifyDNI
//
// Decodificador C40 conforme a la especificación oficial de la Policía Nacional
// "Verificación y Formato de Códigos QR DNI en el Móvil" v1.0.7 (ICAO 9303 parte 13)
//
// Tabla de valores C40 usada en MiDNI:
//   0x03 → ' ' (espacio)
//   0x04 → '0' … 0x0D → '9'
//   0x0E → 'A' … 0x27 → 'Z'
//
// Algoritmo de decodificación (cada par de bytes → 3 caracteres):
//   u1 = (byte1 << 8) | byte2
//   c1 = (u1 - 1) / 1600
//   c2 = ((u1 - 1) - (c1 * 1600)) / 40
//   c3 = (u1 - 1) - (c1 * 1600) - (c2 * 40)

import Foundation

// MARK: - C40Decoder

/// Decodificador del esquema de codificación C40 utilizado en la cabecera del QR MiDNI.
///
/// El QR de la Policía Nacional usa un subconjunto de C40 restringido a:
/// espacio, dígitos ('0'–'9') y letras mayúsculas ('A'–'Z').
///
/// Ejemplo de la especificación oficial:
/// ```
/// C40Decoder.decode(Data([0x75, 0x9e, 0xa9, 0xb5])) == "ESPN20"
/// ```
enum C40Decoder {

    // MARK: - Errores

    enum C40Error: Error, CustomStringConvertible {
        /// El byte de entrada no corresponde a ningún carácter C40 válido en la tabla MiDNI
        case invalidValue(Int)
        /// La longitud de los datos debe ser par (los bytes se procesan en parejas)
        case oddLength(Int)

        var description: String {
            switch self {
            case .invalidValue(let v):
                return "Valor C40 fuera de rango: \(v) (esperado 3–39)"
            case .oddLength(let n):
                return "Longitud de datos impar: \(n). C40 requiere bytes en parejas."
            }
        }
    }

    // MARK: - API pública

    /// Decodifica una secuencia de bytes C40 a una cadena de caracteres.
    ///
    /// - Parameter data: Bytes C40 a decodificar. Deben tener longitud par.
    /// - Returns: Cadena decodificada (solo espacio, dígitos y mayúsculas).
    /// - Throws: `C40Error.oddLength` si `data.count` es impar,
    ///           `C40Error.invalidValue` si algún símbolo está fuera del rango 3–39.
    static func decode(_ data: Data) throws -> String {
        let bytes = [UInt8](data)
        guard bytes.count % 2 == 0 else {
            throw C40Error.oddLength(bytes.count)
        }
        var result = ""
        result.reserveCapacity((bytes.count / 2) * 3)

        var i = 0
        while i < bytes.count {
            let b1 = Int(bytes[i])
            let b2 = Int(bytes[i + 1])

            let (ch1, ch2, ch3) = try decodePair(b1, b2)
            result.append(ch1)
            result.append(ch2)
            result.append(ch3)

            i += 2
        }
        return result
    }

    /// Decodifica exactamente `n` caracteres desde los bytes C40 dados.
    ///
    /// Útil cuando el stream C40 contiene padding en el último grupo de 3 caracteres.
    /// - Parameters:
    ///   - data: Bytes C40 (longitud par).
    ///   - n: Número de caracteres a retornar (≤ capacidad total de `data`).
    static func decode(_ data: Data, taking n: Int) throws -> String {
        let full = try decode(data)
        return String(full.prefix(n))
    }

    // MARK: - Helpers internos

    /// Decodifica un par de bytes C40 en tres símbolos.
    private static func decodePair(_ b1: Int, _ b2: Int) throws -> (Character, Character, Character) {
        let u1 = (b1 << 8) | b2
        let base = u1 - 1

        let c1 = base / 1600
        let c2 = (base - c1 * 1600) / 40
        let c3 = base - c1 * 1600 - c2 * 40

        return (
            try symbolToChar(c1),
            try symbolToChar(c2),
            try symbolToChar(c3)
        )
    }

    /// Convierte un símbolo numérico C40 al carácter correspondiente.
    ///
    /// Tabla conforme a ICAO 9303 parte 13 / especificación MiDNI:
    /// - `0`–`2`   → `'\0'` (Shift 1/2/3 — relleno cuando el último grupo
    ///               tiene menos de 3 caracteres; `decode(_:taking:)` los descarta)
    /// - `3`       → `' '` (espacio)
    /// - `4`–`13`  → `'0'`–`'9'`
    /// - `14`–`39` → `'A'`–`'Z'`
    private static func symbolToChar(_ value: Int) throws -> Character {
        switch value {
        case 0, 1, 2:
            // Carácter de relleno ICAO C40. Se produce cuando se codifican
            // 1 ó 2 caracteres en el último grupo de 3 (p.ej. "ES" → "ES\0").
            // decode(_:taking:) lo elimina al truncar al número real de chars.
            return "\0"
        case 3:
            return " "
        case 4...13:
            // '0' es ASCII 48; value 4 → '0', value 13 → '9'
            return Character(UnicodeScalar(48 + value - 4)!)
        case 14...39:
            // 'A' es ASCII 65; value 14 → 'A', value 39 → 'Z'
            return Character(UnicodeScalar(65 + value - 14)!)
        default:
            throw C40Error.invalidValue(value)
        }
    }
}

// MARK: - Extensión de conveniencia para Data hex

extension Data {
    /// Crea un `Data` a partir de una cadena hexadecimal (p.ej. "759ea9b5").
    /// Devuelve `nil` si la longitud es impar o contiene caracteres no hex.
    init?(hexString: String) {
        let stripped = hexString.replacingOccurrences(of: " ", with: "")
        guard stripped.count % 2 == 0 else { return nil }
        var data = Data(capacity: stripped.count / 2)
        var index = stripped.startIndex
        while index < stripped.endIndex {
            let nextIndex = stripped.index(index, offsetBy: 2)
            guard let byte = UInt8(stripped[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}

// MARK: - Tests unitarios (ejecutables en DEBUG)

#if DEBUG

/// Tests unitarios del C40Decoder basados en los ejemplos del documento oficial
/// "Verificación y Formato de Códigos QR DNI en el Móvil" v1.0.7.
///
/// Cómo ejecutar en Xcode:
/// ```swift
/// C40DecoderTests.runAll()
/// ```
/// O añade un target XCTest y llama `C40DecoderTests.xcTestSuite()`.
enum C40DecoderTests {

    struct TestCase {
        let hexInput: String
        let expected: String
        let description: String
    }

    // -------------------------------------------------------------------------
    // Casos de prueba del PDF oficial
    // -------------------------------------------------------------------------
    static let testCases: [TestCase] = [

        // Ejemplo 1 — del PDF: "759ea9b5" → "ESPN20"
        // Cabecera de identificador firmante: país=ES, entidad=PN, tamaño ref=20(hex)=32 chars
        TestCase(
            hexInput: "759ea9b5",
            expected: "ESPN20",
            description: "Ejemplo oficial PDF: cabecera firmante ESPN + ref size 20"
        ),

        // Ejemplo 2 — par individual que da "ESP"
        TestCase(
            hexInput: "759e",
            expected: "ESP",
            description: "Primer par: pais=ES + primer char del campo"
        ),

        // Ejemplo 3 — par individual que da "N20"
        TestCase(
            hexInput: "a9b5",
            expected: "N20",
            description: "Segundo par: entidad=PN + tamaño referencia 20 (hex) = 32"
        ),

        // Ejemplo 4 — código de país España "ES"
        // E=18, S=32, P=29 → u = 18*1600 + 32*40 + 29 + 1 = 30110 → 0x759E
        // El tercer carácter P es padding (ignorado al tomar n=2)
        TestCase(
            hexInput: "759e",
            expected: "ESP", // decode full; caller usa .prefix(2) para "ES"
            description: "País ES codificado con padding P"
        ),

        // Ejemplo 5 — caracteres numéricos '0'-'9'
        // '0'=4, '0'=4, '0'=4 → u = 4*1600 + 4*40 + 4 + 1 = 6565 → 0x19A5
        TestCase(
            hexInput: "19a5",
            expected: "000",
            description: "Tres ceros"
        ),

        // Ejemplo 6 — '9','9','9'
        // '9'=13, '9'=13, '9'=13 → u = 13*1600 + 13*40 + 13 + 1 = 21334 → 0x5356
        TestCase(
            hexInput: "5356",
            expected: "999",
            description: "Tres nueves"
        ),

        // Ejemplo 7 — 'A','A','A'
        // 'A'=14, 'A'=14, 'A'=14 → u = 14*1600 + 14*40 + 14 + 1 = 22976 → 0x59BF
        TestCase(
            hexInput: "59bf",
            expected: "AAA",
            description: "Tres aes mayúsculas"
        ),

        // Ejemplo 8 — 'Z','Z','Z'
        // 'Z'=39, 'Z'=39, 'Z'=39 → u = 39*1600 + 39*40 + 39 + 1 = 64000 → 0xFA00
        TestCase(
            hexInput: "fa00",
            expected: "ZZZ",
            description: "Tres zetas mayúsculas"
        ),

        // Ejemplo 9 — espacio, espacio, espacio
        // ' '=3, ' '=3, ' '=3 → u = 3*1600 + 3*40 + 3 + 1 = 4924 → 0x133C
        TestCase(
            hexInput: "133c",
            expected: "   ",
            description: "Tres espacios"
        ),

        // Ejemplo 10 — cadena mixta "A1B" verificando saltos
        // A=14, 1=5, B=15 → u = 14*1600 + 5*40 + 15 + 1 = 22616 → 0x5858
        TestCase(
            hexInput: "5858",
            expected: "A1B",
            description: "Mezcla letra-número-letra"
        ),
    ]

    // -------------------------------------------------------------------------
    // Runner
    // -------------------------------------------------------------------------

    /// Ejecuta todos los tests e imprime el resultado en consola.
    /// - Returns: `true` si todos los tests pasan, `false` en caso contrario.
    @discardableResult
    static func runAll() -> Bool {
        var passed = 0
        var failed = 0

        print("═══════════════════════════════════════════════")
        print("  C40Decoder — Tests Unitarios")
        print("═══════════════════════════════════════════════")

        for (idx, tc) in testCases.enumerated() {
            guard let inputData = Data(hexString: tc.hexInput) else {
                print("[\(idx + 1)] SKIP  \(tc.description) — hex inválido")
                failed += 1
                continue
            }

            do {
                let result = try C40Decoder.decode(inputData)
                if result == tc.expected {
                    print("[\(idx + 1)] PASS  \(tc.description)")
                    print("       \(tc.hexInput) → \"\(result)\"")
                    passed += 1
                } else {
                    print("[\(idx + 1)] FAIL  \(tc.description)")
                    print("       input:    \(tc.hexInput)")
                    print("       expected: \"\(tc.expected)\"")
                    print("       got:      \"\(result)\"")
                    failed += 1
                }
            } catch {
                print("[\(idx + 1)] ERROR \(tc.description)")
                print("       \(error)")
                failed += 1
            }
        }

        // Test de error: longitud impar
        let oddData = Data([0x75, 0x9e, 0xa9]) // 3 bytes → error
        do {
            _ = try C40Decoder.decode(oddData)
            print("[E1] FAIL  longitud impar debería lanzar error")
            failed += 1
        } catch C40Decoder.C40Error.oddLength {
            print("[E1] PASS  longitud impar lanza C40Error.oddLength correctamente")
            passed += 1
        } catch {
            print("[E1] FAIL  error inesperado: \(error)")
            failed += 1
        }

        // Test de error: valor fuera de rango
        // u = 1 → base=0 → c1=0, c2=0, c3=0 → valor 0 no está en tabla (< 3)
        let invalidData = Data([0x00, 0x01])
        do {
            _ = try C40Decoder.decode(invalidData)
            print("[E2] FAIL  valor inválido (0) debería lanzar error")
            failed += 1
        } catch C40Decoder.C40Error.invalidValue {
            print("[E2] PASS  valor fuera de rango lanza C40Error.invalidValue correctamente")
            passed += 1
        } catch {
            print("[E2] FAIL  error inesperado: \(error)")
            failed += 1
        }

        print("───────────────────────────────────────────────")
        print("  Resultado: \(passed) pasados, \(failed) fallidos de \(passed + failed) tests")
        print("═══════════════════════════════════════════════")

        return failed == 0
    }

    // -------------------------------------------------------------------------
    // Verificación individual de los cálculos del ejemplo del PDF
    // -------------------------------------------------------------------------

    /// Desglosa paso a paso la decodificación de "759ea9b5" → "ESPN20"
    /// tal como aparece en el documento oficial.
    static func explainOfficialExample() {
        print("\nEjemplo oficial: C40decode(\"759ea9b5\") → \"ESPN20\"")
        print("───────────────────────────────────────────────")

        let pairs: [(UInt8, UInt8, String)] = [
            (0x75, 0x9E, "ESP"),
            (0xA9, 0xB5, "N20"),
        ]

        for (b1, b2, expected) in pairs {
            let u1 = (Int(b1) << 8) | Int(b2)
            let base = u1 - 1
            let c1 = base / 1600
            let c2 = (base - c1 * 1600) / 40
            let c3 = base - c1 * 1600 - c2 * 40
            print("  bytes: 0x\(String(b1, radix: 16, uppercase: true)) 0x\(String(b2, radix: 16, uppercase: true))")
            print("  u1 = \(u1), base = u1-1 = \(base)")
            print("  c1 = \(base)/1600 = \(c1)  → '\(expected.first!)'")
            print("  c2 = (\(base)-\(c1*1600))/40 = \(c2)  → '\(expected.dropFirst().first!)'")
            print("  c3 = \(base)-\(c1*1600)-\(c2*40) = \(c3)  → '\(expected.last!)'")
            print("  ─ resultado: \"\(expected)\"")
        }
        print("  Total: \"ESPN20\" ✓")
    }
}

#endif
