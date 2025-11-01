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

            // Obtener el payload del QR
            var qrData: Data?

            // Método 1: payloadStringValue con ISO Latin 1
            if let payloadString = barcode.payloadStringValue {
                print("📲 Payload string length: \(payloadString.count)")

                // Intentar ISO Latin 1 primero (para datos binarios)
                if let data = payloadString.data(using: .isoLatin1) {
                    qrData = data
                    print("✅ Payload extraído con ISO Latin 1: \(data.count) bytes")
                }
                // Fallback a UTF-8
                else if let data = payloadString.data(using: .utf8) {
                    qrData = data
                    print("✅ Payload extraído con UTF-8: \(data.count) bytes")
                }
            }

            // Si tenemos datos, procesarlos
            if let data = qrData {
                print("📦 Procesando \(data.count) bytes")
                print("📦 Primeros 20 bytes (hex): \(data.prefix(20).map { String(format: "%02x", $0) }.joined(separator: " "))")

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
