//
//  QRScannerView.swift
//  DecodePoliciaDNI
//
//  Created by Jesus Mora on 1/11/25.
//

import SwiftUI
import AVFoundation
import AudioToolbox
import Combine
import CoreImage
import Vision

struct QRScannerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = QRScannerViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                // Vista de la cámara
                CameraPreview(session: viewModel.session)
                    .edgesIgnoringSafeArea(.all)

                // Overlay con marco de escaneo
                VStack {
                    Spacer()

                    // Marco de escaneo
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green, lineWidth: 4)
                        .frame(width: 280, height: 280)

                    Spacer()

                    // Instrucciones
                    Text("Escanea el código QR de tu miDNI")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                }

                // Estado de escaneo
                if viewModel.isScanning {
                    Color.green.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.green)
                                Text("¡QR Detectado!")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        )
                }
            }
            .navigationBarTitle("Escanear miDNI", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cerrar") {
                dismiss()
            })
            .onAppear {
                viewModel.checkCameraPermission()
            }
            .onDisappear {
                viewModel.stopScanning()
            }
        }
    }
}

// MARK: - ViewModel
class QRScannerViewModel: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var scanError: String?

    let session = AVCaptureSession()
    private let scanner = MiDNIQRScanner()
    private var setupComplete = false

    func checkCameraPermission() {
        print("🔍 Verificando permisos de cámara...")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("✅ Permisos de cámara autorizados")
            setupCamera()
        case .notDetermined:
            print("⏳ Solicitando permisos de cámara...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    print("✅ Usuario concedió permisos de cámara")
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.scanError = "Permiso de cámara denegado"
                        print("❌ Usuario denegó permisos de cámara")
                    }
                }
            }
        case .denied, .restricted:
            scanError = "Permiso de cámara denegado. Por favor, habilítalo en Configuración."
            print("❌ Permiso de cámara denegado o restringido")
        @unknown default:
            break
        }
    }

    private func setupCamera() {
        guard !setupComplete else {
            print("⚠️ Cámara ya configurada, saltando setup")
            return
        }

        print("🎥 Iniciando configuración de cámara...")
        session.beginConfiguration()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ No se pudo acceder a la cámara")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)

            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                print("✅ Entrada de video agregada")
            } else {
                print("❌ No se pudo agregar la entrada de video")
                return
            }

            // Usar AVCaptureVideoDataOutput para Vision framework
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))

            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                print("✅ Salida de video configurada para Vision")
            } else {
                print("❌ No se pudo agregar la salida de video")
                return
            }

            session.commitConfiguration()
            setupComplete = true

            print("✅ Cámara configurada correctamente")
            print("📸 Iniciando sesión de captura...")

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
                DispatchQueue.main.async {
                    print("✅ Sesión de captura iniciada y corriendo")
                    print("🔍 Esperando código QR...")
                }
            }

        } catch {
            print("❌ Error al configurar la cámara: \(error.localizedDescription)")
            scanError = "Error al configurar la cámara"
        }
    }

    func stopScanning() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
                print("🛑 Sesión de captura detenida")
            }
        }
    }

    deinit {
        stopScanning()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension QRScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {

        // Evitar procesar si ya estamos escaneando
        guard !isScanning else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ Error en Vision request: \(error.localizedDescription)")
                return
            }

            guard let results = request.results as? [VNBarcodeObservation],
                  let barcode = results.first else {
                return
            }

            print("🎯 VISION: QR detectado! Tipo: \(barcode.symbology.rawValue)")

            // Obtener el payload del QR desde el descriptor
            var qrData: Data?

            // Usar el descriptor para obtener los datos raw
            if let descriptor = barcode.barcodeDescriptor as? CIQRCodeDescriptor {
                let payload = descriptor.errorCorrectedPayload
                print("📦 Error corrected payload: \(payload.count) bytes")
                print("📦 Primeros 30 bytes (hex): \(payload.prefix(30).map { String(format: "%02x", $0) }.joined(separator: " "))")

                // Parsear el payload del QR para extraer solo los datos del usuario
                if let extractedData = self.extractUserDataFromQRPayload(payload) {
                    qrData = extractedData
                    print("✅ Datos de usuario extraídos: \(extractedData.count) bytes")
                    print("📦 Primeros 20 bytes de datos usuario (hex): \(extractedData.prefix(20).map { String(format: "%02x", $0) }.joined(separator: " "))")
                } else {
                    print("❌ No se pudieron extraer los datos del usuario del payload")
                }
            }

            // Si tenemos datos, procesarlos
            if let data = qrData {
                print("📦 Procesando \(data.count) bytes")

                // Evitar procesar múltiples veces
                DispatchQueue.main.async {
                    self.isScanning = true
                }

                // Vibración
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

                if let miDNI = self.scanner.decodeQRDataFromBytes(data) {
                    self.scanner.printSummary(miDNI)
                    self.showSuccess()
                } else {
                    print("❌ No se pudo decodificar el QR como miDNI")
                    DispatchQueue.main.async {
                        self.isScanning = false
                    }
                }
            } else {
                print("❌ No se pudo extraer el payload del QR")
            }
        }

        // Configurar el request para QR codes
        request.symbologies = [.qr]

        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try requestHandler.perform([request])
        } catch {
            print("❌ Error al ejecutar Vision request: \(error.localizedDescription)")
        }
    }

    /// Extrae los datos del usuario desde el payload del QR
    /// Busca directamente el patrón 0xDC 0x03 (magic constant + versión)
    private func extractUserDataFromQRPayload(_ payload: Data) -> Data? {
        print("🔍 Buscando patrón 0xDC 0x03 en payload de \(payload.count) bytes...")

        // Buscar el patrón específico: 0xDC (magic) seguido de 0x03 (versión)
        for i in 0..<(payload.count - 1) {
            if payload[i] == 0xDC && payload[i + 1] == 0x03 {
                print("✅ Patrón 0xDC 0x03 encontrado en índice \(i)")

                // Extraer desde 0xDC hasta el final del payload
                let userData = Data(payload[i...])
                print("✅ Extrayendo \(userData.count) bytes desde índice \(i)")

                // Imprimir TODOS los bytes en formato hexadecimal
                print("\n" + String(repeating: "=", count: 80))
                print("📋 DUMP COMPLETO DE BYTES (para comparar con PDF)")
                print(String(repeating: "=", count: 80))

                let bytesPerLine = 16

                for lineStart in stride(from: 0, to: userData.count, by: bytesPerLine) {
                    let lineEnd = min(lineStart + bytesPerLine, userData.count)
                    let lineData = userData[lineStart..<lineEnd]
                    let hexLine = lineData.map { String(format: "%02x", $0) }.joined(separator: " ")
                    let offset = String(format: "%04x", lineStart)
                    print("\(offset) - \(hexLine)")
                }

                print(String(repeating: "=", count: 80) + "\n")

                return userData
            }
        }

        // Si no encontramos el patrón correcto, mostrar información de debug
        print("❌ Patrón 0xDC 0x03 no encontrado en el payload")

        // Buscar todas las ocurrencias de 0xDC para debug
        var dcIndices: [Int] = []
        for i in 0..<payload.count {
            if payload[i] == 0xDC {
                let nextByte = i + 1 < payload.count ? payload[i + 1] : 0x00
                dcIndices.append(i)
                print("   Encontrado 0xDC en índice \(i), siguiente byte: 0x\(String(format: "%02x", nextByte))")
            }
        }

        if dcIndices.isEmpty {
            print("   No se encontró ningún byte 0xDC en el payload")
        }

        print("📦 Payload completo (primeros 100 bytes):")
        let hexDump = payload.prefix(100).map { String(format: "%02x", $0) }.joined(separator: " ")
        print("   \(hexDump)")

        return nil
    }

    private func showSuccess() {
        DispatchQueue.main.async {
            self.isScanning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.isScanning = false
            }
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

#Preview {
    QRScannerView()
}
