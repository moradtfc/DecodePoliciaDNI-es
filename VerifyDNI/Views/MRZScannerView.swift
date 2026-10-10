// MRZScannerView.swift
// VerifyDNI
//
// Escáner MRZ usando Vision + AVFoundation.
//
// Estrategia de precisión:
//   1. Validación de check digits ICAO 9303 — descarta cualquier frame donde
//      el número de documento, la fecha de nacimiento o la caducidad no
//      superen su dígito de control. Esto elimina los falsos positivos de OCR.
//   2. Consenso de 2 frames — el mismo resultado (docNum + dob + exp) debe
//      aparecer en 2 frames consecutivos válidos antes de emitir. Protege
//      contra coincidencias puntuales que pasen el checksum por azar.
//   3. Throttle de 200 ms — procesa máximo 5 fps para evitar frames borrosos
//      entre movimientos de cámara.
//   4. Corrección de errores OCR selectiva — en campos numéricos se aplica
//      fixDigits; en el campo de documento se prueban variantes (raw,
//      fixLetters, fixDigits) y se acepta la primera que valide el checksum.

import SwiftUI
import AVFoundation
import Vision

// MARK: - MRZScanResult

struct MRZScanResult {
    let documentNumber: String
    let dateOfBirth:    Date?
    let expiryDate:     Date?
    let dobString:      String   // yyMMdd
    let expiryString:   String   // yyMMdd
    let givenNames:     String
    let surnames:       String
    /// Código ISO 3166-1 alpha-3 del MRZ. "ESP" = DNI, otro valor = TIE.
    let nationality:    String?
}

// MARK: - MRZScannerView (UIViewRepresentable)

struct MRZScannerView: UIViewRepresentable {

    let onResult: (MRZScanResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.setup(delegate: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

        let onResult: (MRZScanResult) -> Void
        private var didFindMRZ = false

        // ── Consenso ──────────────────────────────────────────────────────────
        // Un resultado debe aparecer en `requiredConsensus` frames consecutivos
        // (con check digits válidos) antes de emitirse.
        private let requiredConsensus = 2
        private var candidateKey:    String        = ""
        private var candidateCount:  Int           = 0
        private var candidateResult: MRZScanResult?

        // ── Throttle de frames ────────────────────────────────────────────────
        // A 30 fps un movimiento de 100 ms produce ~3 frames borrosos seguidos.
        // Procesamos como máximo a 5 fps (200 ms) para descartar transiciones.
        private let frameInterval: TimeInterval = 0.20
        private var lastFrameTime: TimeInterval = 0

        private let textRequest: VNRecognizeTextRequest = {
            let r = VNRecognizeTextRequest()
            r.recognitionLevel       = .accurate
            r.usesLanguageCorrection = false
            r.recognitionLanguages   = ["en-US"]
            r.minimumTextHeight      = 0.01
            return r
        }()

        init(onResult: @escaping (MRZScanResult) -> Void) {
            self.onResult = onResult
        }

        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            let now = CACurrentMediaTime()
            guard !didFindMRZ,
                  now - lastFrameTime >= frameInterval,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else { return }
            lastFrameTime = now

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                orientation: .right,
                                                options: [:])
            do {
                try handler.perform([textRequest])
                let texts = textRequest.results?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []

                guard let result = parseMRZ(from: texts) else {
                    // Frame inválido — no reiniciamos el consenso para no castigar
                    // frames buenos seguidos de uno con distorsión puntual.
                    return
                }

                let key = "\(result.documentNumber)|\(result.dobString)|\(result.expiryString)"

                if key == candidateKey {
                    candidateCount += 1
                } else {
                    // Nuevo candidato (diferente resultado) → reiniciar conteo
                    candidateKey    = key
                    candidateCount  = 1
                    candidateResult = result
                }

                if candidateCount >= requiredConsensus {
                    didFindMRZ = true
                    let final = candidateResult ?? result
                    print("✅ [MRZ] Consenso alcanzado (\(candidateCount) frames): \(key)")
                    DispatchQueue.main.async { self.onResult(final) }
                }
            } catch {
                print("🔴 [MRZ] Vision error: \(error)")
            }
        }

        // MARK: - Algoritmo ICAO check digit (idéntico a calcCheckSum en NFCViewModel)

        private func icaoCheckDigit(_ input: String) -> Int {
            let weights = [7, 3, 1]
            var sum = 0
            for (i, c) in input.enumerated() {
                let v: Int
                if let d = c.wholeNumberValue { v = d }
                else if c >= "A" && c <= "Z"  { v = Int(c.asciiValue! - 55) }
                else                           { v = 0 }   // '<' o desconocido
                sum += v * weights[i % 3]
            }
            return sum % 10
        }

        // MARK: - MRZ Parsing

        private func parseMRZ(from texts: [String]) -> MRZScanResult? {
            let cleaned = texts
                .map { cleanLine($0) }
                .filter { isMRZCandidate($0) }

            // TD1: 3 líneas × 30 chars (DNI español / TIE)
            let td1 = cleaned.filter { $0.count >= 28 && $0.count <= 32 }
            if td1.count >= 2, let result = parseTD1(lines: td1) { return result }

            // TD3: 2 líneas × 44 chars (pasaporte)
            let td3 = cleaned.filter { $0.count >= 42 && $0.count <= 46 }
            if td3.count >= 2, let result = parseTD3(lines: td3) { return result }

            return nil
        }

        private func cleanLine(_ raw: String) -> String {
            raw
                .uppercased()
                .replacingOccurrences(of: " ",  with: "<")
                .replacingOccurrences(of: "«",  with: "<")
                .replacingOccurrences(of: "»",  with: "<")
                .filter { $0.isLetter || $0.isNumber || $0 == "<" }
        }

        private func isMRZCandidate(_ line: String) -> Bool {
            line.count >= 28 && line == line.uppercased()
        }

        // MARK: - TD1 Line Identification

        private func isTD1Line1(_ s: String) -> Bool {
            guard s.count >= 5 else { return false }
            let chars = Array(s.prefix(5))
            return chars[0].isLetter
                && (chars[1].isLetter || chars[1] == "<")
                && chars[2].isLetter && chars[3].isLetter && chars[4].isLetter
        }

        /// Línea 2 de TD1 empieza con 6 dígitos (fecha de nacimiento YYMMDD).
        /// Aplicamos fixDigits antes de comprobar para corregir O→0, I→1, etc.
        private func isTD1Line2(_ s: String) -> Bool {
            guard s.count >= 6 else { return false }
            return String(s.prefix(6)).map { fixDigitChar($0) }.allSatisfy(\.isNumber)
        }

        // MARK: - Parseo TD1 con validación de check digits

        private func parseTD1(lines: [String]) -> MRZScanResult? {
            var line1: String? = nil
            var line2: String? = nil
            var line3: String? = nil

            for line in lines {
                if isTD1Line2(line)      { if line2 == nil { line2 = line } }
                else if isTD1Line1(line) { if line1 == nil { line1 = line } }
                else                     { line3 = line }
            }

            guard let l1 = line1, let l2 = line2 else {
                print("🔴 [MRZ] TD1 — no se identificaron línea1/línea2")
                return nil
            }

            let p1 = pad(l1, to: 30)
            let p2 = pad(l2, to: 30)

            print("🔵 [MRZ] TD1 p1: \(p1)")
            print("🔵 [MRZ] TD1 p2: \(p2)")

            // ── Check digit: número de documento (p1 pos 5-13, check en 14) ─────
            let docField     = substring(p1, from: 5, length: 9)   // incluye '<'
            let docCheckChar = fixDigits(substring(p1, from: 14, length: 1))
            guard let docCheckExpected = Int(docCheckChar) else {
                print("🔴 [MRZ] TD1 — check digit doc no es dígito: '\(docCheckChar)'")
                return nil
            }
            // Intentamos raw, fixLetters y fixDigits: el primero que valide es el correcto
            let docVariants = [docField, fixLetters(docField), fixDigitsStr(docField)]
            guard let validDocField = docVariants.first(where: {
                icaoCheckDigit($0) == docCheckExpected
            }) else {
                print("🔴 [MRZ] TD1 — doc checksum fallido: '\(docField)' exp=\(docCheckExpected) calc=\(icaoCheckDigit(docField))")
                return nil
            }
            let docRaw = validDocField.replacingOccurrences(of: "<", with: "")
            guard docRaw.count >= 5 else {
                print("🔴 [MRZ] TD1 — docNum demasiado corto: '\(docRaw)'")
                return nil
            }

            // ── Check digit: fecha de nacimiento (p2 pos 0-5, check en 6) ───────
            let dobField     = fixDigitsStr(substring(p2, from: 0, length: 6))
            let dobCheckChar = fixDigits(substring(p2, from: 6, length: 1))
            guard dobField.count == 6, dobField.allSatisfy(\.isNumber),
                  let dobCheckExpected = Int(dobCheckChar),
                  icaoCheckDigit(dobField) == dobCheckExpected else {
                print("🔴 [MRZ] TD1 — DOB checksum fallido: '\(dobField)'")
                return nil
            }

            // ── Check digit: fecha de caducidad (p2 pos 8-13, check en 14) ──────
            let expField     = fixDigitsStr(substring(p2, from: 8, length: 6))
            let expCheckChar = fixDigits(substring(p2, from: 14, length: 1))
            guard expField.count == 6, expField.allSatisfy(\.isNumber),
                  let expCheckExpected = Int(expCheckChar),
                  icaoCheckDigit(expField) == expCheckExpected else {
                print("🔴 [MRZ] TD1 — EXP checksum fallido: '\(expField)'")
                return nil
            }

            // ── Nacionalidad (p2 pos 15-17) ──────────────────────────────────────
            let natRaw = fixLetters(
                substring(p2, from: 15, length: 3)
                    .replacingOccurrences(of: "<", with: "")
            )
            let nationality = natRaw.count == 3 ? natRaw : nil

            print("🟢 [MRZ] TD1 — doc:\(docRaw) dob:\(dobField) exp:\(expField) nat:\(nationality ?? "?")")

            var givenNames = ""
            var surnames   = ""
            if let l3 = line3 {
                extractNames(from: pad(l3, to: 30), given: &givenNames, sur: &surnames)
            }

            return MRZScanResult(
                documentNumber: docRaw,
                dateOfBirth:    mrzDate(dobField),
                expiryDate:     mrzDate(expField),
                dobString:      dobField,
                expiryString:   expField,
                givenNames:     givenNames,
                surnames:       surnames,
                nationality:    nationality
            )
        }

        // MARK: - Parseo TD3 con validación de check digits

        private func parseTD3(lines: [String]) -> MRZScanResult? {
            guard lines.count >= 2 else { return nil }

            var line1: String? = lines.first { $0.hasPrefix("P") && !isTD1Line2($0) }
            var line2: String? = lines.first { isTD1Line2($0) || ($0.first?.isNumber ?? false) }
            if line1 == nil { line1 = lines[0] }
            if line2 == nil { line2 = lines[1] }
            guard let l1 = line1, let l2 = line2 else { return nil }

            let p1 = pad(l1, to: 44)
            let p2 = pad(l2, to: 44)

            // ── Check digit: número de documento (p2 pos 0-8, check en 9) ───────
            let docField     = substring(p2, from: 0, length: 9)
            let docCheckChar = fixDigits(substring(p2, from: 9, length: 1))
            guard let docCheckExpected = Int(docCheckChar) else { return nil }
            let docVariants = [docField, fixLetters(docField), fixDigitsStr(docField)]
            guard let validDocField = docVariants.first(where: {
                icaoCheckDigit($0) == docCheckExpected
            }) else {
                print("🔴 [MRZ] TD3 — doc checksum fallido: '\(docField)' exp=\(docCheckExpected)")
                return nil
            }
            let docRaw = validDocField.replacingOccurrences(of: "<", with: "")
            guard docRaw.count >= 5 else { return nil }

            // ── Check digit: fecha de nacimiento (p2 pos 13-18, check en 19) ────
            let dobField     = fixDigitsStr(substring(p2, from: 13, length: 6))
            let dobCheckChar = fixDigits(substring(p2, from: 19, length: 1))
            guard dobField.count == 6, dobField.allSatisfy(\.isNumber),
                  let dobCheckExpected = Int(dobCheckChar),
                  icaoCheckDigit(dobField) == dobCheckExpected else {
                print("🔴 [MRZ] TD3 — DOB checksum fallido: '\(dobField)'")
                return nil
            }

            // ── Check digit: fecha de caducidad (p2 pos 21-26, check en 27) ─────
            let expField     = fixDigitsStr(substring(p2, from: 21, length: 6))
            let expCheckChar = fixDigits(substring(p2, from: 27, length: 1))
            guard expField.count == 6, expField.allSatisfy(\.isNumber),
                  let expCheckExpected = Int(expCheckChar),
                  icaoCheckDigit(expField) == expCheckExpected else {
                print("🔴 [MRZ] TD3 — EXP checksum fallido: '\(expField)'")
                return nil
            }

            // ── Nacionalidad (p2 pos 10-12) ──────────────────────────────────────
            let natRaw = fixLetters(
                substring(p2, from: 10, length: 3)
                    .replacingOccurrences(of: "<", with: "")
            )
            let nationality = natRaw.count == 3 ? natRaw : nil

            print("🟢 [MRZ] TD3 — doc:\(docRaw) dob:\(dobField) exp:\(expField) nat:\(nationality ?? "?")")

            var givenNames = ""
            var surnames   = ""
            extractNames(from: substring(p1, from: 5, length: 39),
                         given: &givenNames, sur: &surnames)

            return MRZScanResult(
                documentNumber: docRaw,
                dateOfBirth:    mrzDate(dobField),
                expiryDate:     mrzDate(expField),
                dobString:      dobField,
                expiryString:   expField,
                givenNames:     givenNames,
                surnames:       surnames,
                nationality:    nationality
            )
        }

        // MARK: - Helpers de extracción y corrección OCR

        private func extractNames(from field: String,
                                  given: inout String,
                                  sur:   inout String) {
            let parts = field.components(separatedBy: "<<")
            if parts.count >= 2 {
                sur   = parts[0].replacingOccurrences(of: "<", with: " ")
                              .trimmingCharacters(in: .whitespaces)
                given = parts[1].replacingOccurrences(of: "<", with: " ")
                              .trimmingCharacters(in: .whitespaces)
            }
        }

        /// Campos LETRAS: invierte las confusiones dígito→letra más comunes del MRZ OCR.
        /// 0→O  1→I  3→E  5→S  8→B
        private func fixLetters(_ s: String) -> String {
            String(s.map { c -> Character in
                switch c {
                case "0": return "O"
                case "1": return "I"
                case "3": return "E"
                case "5": return "S"
                case "8": return "B"
                default:  return c
                }
            })
        }

        /// Campos NUMÉRICOS: invierte las confusiones letra→dígito más comunes.
        /// O→0  I→1  S→5  B→8  Z→2
        private func fixDigitsStr(_ s: String) -> String {
            String(s.map { fixDigitChar($0) })
        }

        /// Versión single-char de fixDigits para identificación de líneas.
        private func fixDigitChar(_ c: Character) -> Character {
            switch c {
            case "O": return "0"
            case "I": return "1"
            case "S": return "5"
            case "B": return "8"
            case "Z": return "2"
            default:  return c
            }
        }

        /// Corrige un único dígito (para check chars que deben ser 0-9).
        private func fixDigits(_ s: String) -> String { fixDigitsStr(s) }

        /// Pad a exactamente `length` chars: rellena con '<' si es corta,
        /// trunca por la izquierda si es más larga (los primeros chars son los más fiables).
        private func pad(_ s: String, to length: Int) -> String {
            if s.count == length { return s }
            if s.count > length  { return String(s.prefix(length)) }
            return s.padding(toLength: length, withPad: "<", startingAt: 0)
        }

        private func substring(_ s: String, from: Int, length: Int) -> String {
            guard from < s.count else { return "" }
            let start = s.index(s.startIndex, offsetBy: from)
            let end   = s.index(start, offsetBy: min(length, s.count - from))
            return String(s[start..<end])
        }

        private func mrzDate(_ yymmdd: String) -> Date? {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyMMdd"
            fmt.locale     = Locale(identifier: "en_US_POSIX")
            return fmt.date(from: yymmdd)
        }
    }
}

// MARK: - CameraPreviewView

final class CameraPreviewView: UIView {

    private var captureSession: AVCaptureSession?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    func setup(delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        let session = AVCaptureSession()
        // 1920×1080 mejora la nitidez del OCR respecto a 720p
        session.sessionPreset = .hd1920x1080

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video, position: .back),
            let input  = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            print("🔴 [MRZ] No se pudo iniciar la cámara")
            return
        }

        // Autoenfoque continuo para mantener nitidez sobre el DNI
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            try? camera.lockForConfiguration()
            camera.focusMode = .continuousAutoFocus
            camera.unlockForConfiguration()
        }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(
            delegate,
            queue: DispatchQueue(label: "mrz.vision.queue", qos: .userInitiated)
        )
        if session.canAddOutput(output) { session.addOutput(output) }

        previewLayer.session      = session
        previewLayer.videoGravity = .resizeAspectFill
        captureSession            = session

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }

    deinit { captureSession?.stopRunning() }
}
