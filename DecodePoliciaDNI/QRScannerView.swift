//
//  QRScannerView.swift
//  DecodePoliciaDNI
//
//  Created by Jesus Mora on 1/11/25.
//

import SwiftUI
import AVFoundation

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
class QRScannerViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scanError: String?

    let session = AVCaptureSession()
    private let scanner = MiDNIQRScanner()
    private var setupComplete = false

    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.scanError = "Permiso de cámara denegado"
                        print("❌ Permiso de cámara denegado")
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
        guard !setupComplete else { return }

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

            let metadataOutput = AVCaptureMetadataOutput()

            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)

                metadataOutput.setMetadataObjectsDelegate(scanner, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]

                print("✅ Salida de metadatos configurada")
            } else {
                print("❌ No se pudo agregar la salida de metadatos")
                return
            }

            session.commitConfiguration()
            setupComplete = true

            print("✅ Cámara configurada correctamente")
            print("📸 Iniciando sesión de captura...")

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
                print("✅ Sesión de captura iniciada")
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
