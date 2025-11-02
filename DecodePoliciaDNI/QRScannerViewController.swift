//
//  QRScannerViewController.swift
//  DecodePoliciaDNI
//
//  Created by Claude on 2/11/25.
//

import UIKit
import AVFoundation
import AudioToolbox
import CoreImage
import Vision

class QRScannerViewController: UIViewController {

    // MARK: - Properties

    private var session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let scanner = MiDNIQRScanner()
    private var setupComplete = false
    private var isScanning = false

    // MARK: - UI Components

    private let scanningFrameView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor.systemGreen.cgColor
        view.layer.borderWidth = 4
        view.layer.cornerRadius = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Escanea el código QR de tu miDNI"
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let successOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let successIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let successLabel: UILabel = {
        let label = UILabel()
        label.text = "¡QR Detectado!"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🎬 QRScannerViewController - viewDidLoad()")
        setupUI()
        setupNavigationBar()
        print("✅ QRScannerViewController - UI configurada")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🎬 QRScannerViewController - viewDidAppear()")
        print("📱 View bounds: \(view.bounds)")
        checkCameraPermission()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    deinit {
        stopScanning()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .black

        // Add success overlay
        view.addSubview(successOverlay)
        successOverlay.addSubview(successIconImageView)
        successOverlay.addSubview(successLabel)

        // Add scanning frame
        view.addSubview(scanningFrameView)

        // Add instruction label
        view.addSubview(instructionLabel)

        // Setup constraints
        NSLayoutConstraint.activate([
            // Success overlay (full screen)
            successOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            successOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            successOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            successOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Success icon
            successIconImageView.centerXAnchor.constraint(equalTo: successOverlay.centerXAnchor),
            successIconImageView.centerYAnchor.constraint(equalTo: successOverlay.centerYAnchor, constant: -30),
            successIconImageView.widthAnchor.constraint(equalToConstant: 80),
            successIconImageView.heightAnchor.constraint(equalToConstant: 80),

            // Success label
            successLabel.topAnchor.constraint(equalTo: successIconImageView.bottomAnchor, constant: 20),
            successLabel.centerXAnchor.constraint(equalTo: successOverlay.centerXAnchor),

            // Scanning frame
            scanningFrameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanningFrameView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanningFrameView.widthAnchor.constraint(equalToConstant: 280),
            scanningFrameView.heightAnchor.constraint(equalToConstant: 280),

            // Instruction label
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            instructionLabel.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupNavigationBar() {
        title = "Escanear miDNI"

        // Add close button
        let closeButton = UIBarButtonItem(
            title: "Cerrar",
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        navigationItem.rightBarButtonItem = closeButton
    }

    // MARK: - Camera Setup

    private func checkCameraPermission() {
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
                    print("❌ Usuario denegó permisos de cámara")
                }
            }
        case .denied, .restricted:
            print("❌ Permiso de cámara denegado o restringido")
            showPermissionAlert()
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

            // Setup preview layer en el main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                let previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = self.view.bounds
                self.view.layer.insertSublayer(previewLayer, at: 0)
                self.previewLayer = previewLayer

                print("✅ Preview layer configurado con frame: \(self.view.bounds)")
                print("📸 Iniciando sesión de captura...")

                // Iniciar la sesión en background thread
                DispatchQueue.global(qos: .userInitiated).async {
                    self.session.startRunning()
                    DispatchQueue.main.async {
                        print("✅ Sesión de captura iniciada y corriendo")
                        print("🔍 Esperando código QR...")
                    }
                }
            }

        } catch {
            print("❌ Error al configurar la cámara: \(error.localizedDescription)")
        }
    }

    private func stopScanning() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
                print("🛑 Sesión de captura detenida")
            }
        }
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }

    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Permiso de Cámara Requerido",
            message: "Por favor, habilita el acceso a la cámara en Configuración para escanear códigos QR.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Configuración", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })

        present(alert, animated: true)
    }

    private func showSuccess() {
        DispatchQueue.main.async { [weak self] in
            self?.isScanning = true
            self?.successOverlay.isHidden = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self?.isScanning = false
                self?.successOverlay.isHidden = true
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension QRScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
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
    /// Los datos están después de mode (4 bits) + character count (16 bits para QR grandes)
    private func extractUserDataFromQRPayload(_ payload: Data) -> Data? {
        print("🔍 Analizando estructura del QR payload de \(payload.count) bytes...")

        guard payload.count >= 3 else {
            print("❌ Payload demasiado pequeño")
            return nil
        }

        // Leer los primeros bits para determinar el modo y longitud
        let byte0 = Int(payload[0])
        let byte1 = Int(payload[1])
        let byte2 = payload.count > 2 ? Int(payload[2]) : 0

        // Mode indicator (primeros 4 bits del byte 0)
        let mode = byte0 >> 4
        print("📊 Mode indicator: \(mode) (4=Byte mode)")

        guard mode == 4 else {
            print("❌ Modo no soportado: \(mode)")
            return nil
        }

        // Para QR grandes (> 150 bytes), character count es de 16 bits
        // Bits 4-19: últimos 4 bits del byte 0 + byte 1 completo + primeros 4 bits del byte 2
        let lengthPart1 = byte0 & 0x0F  // últimos 4 bits del byte 0
        let lengthPart2 = byte1          // byte 1 completo
        let lengthPart3 = byte2 >> 4     // primeros 4 bits del byte 2

        let characterCount = (lengthPart1 << 12) | (lengthPart2 << 4) | lengthPart3
        print("📊 Character count (16 bits): \(characterCount) bytes")

        // Los datos del usuario empiezan en el bit 20 (después de 4 bits de mode + 16 bits de length)
        // Bit 20 está en el byte 2, bit 4
        // Necesitamos extraer desde bit 20 en adelante y realinear a bytes

        var outputData = Data()
        var currentBit = 20  // Empezar desde el bit 20

        // Extraer characterCount bytes de datos
        for _ in 0..<characterCount {
            let byteIndex = currentBit / 8
            let bitOffset = currentBit % 8

            guard byteIndex < payload.count else {
                print("❌ Se acabaron los datos del payload")
                break
            }

            if bitOffset == 0 {
                // Alineado a byte boundary, podemos copiar directamente
                outputData.append(payload[byteIndex])
            } else {
                // No alineado, necesitamos combinar bits de dos bytes consecutivos
                guard byteIndex + 1 < payload.count else {
                    print("❌ No hay suficientes bytes para reconstruir el último byte")
                    break
                }

                let byte1 = Int(payload[byteIndex])
                let byte2 = Int(payload[byteIndex + 1])

                // Tomar los últimos (8 - bitOffset) bits del byte1 y los primeros bitOffset bits del byte2
                let bitsFromByte1 = (byte1 << bitOffset) & 0xFF
                let bitsFromByte2 = (byte2 >> (8 - bitOffset)) & 0xFF
                let reconstructedByte = bitsFromByte1 | bitsFromByte2

                outputData.append(UInt8(reconstructedByte))
            }

            currentBit += 8
        }

        print("✅ Extraídos \(outputData.count) bytes de datos de usuario")
        print("📦 Primeros 10 bytes: \(outputData.prefix(10).map { String(format: "%02x", $0) }.joined(separator: " "))")

        // Verificar que empieza con 0xDC 0x03
        if outputData.count >= 2 {
            let magic = outputData[0]
            let version = outputData[1]
            print("🔍 Magic: 0x\(String(format: "%02x", magic)), Version: 0x\(String(format: "%02x", version))")

            if magic == 0xDC && version == 0x03 {
                print("✅ Estructura miDNI válida detectada!")

                // Imprimir hex dump completo
                print("\n" + String(repeating: "=", count: 80))
                print("📋 DUMP COMPLETO DE BYTES (para comparar con PDF)")
                print(String(repeating: "=", count: 80))

                let bytesPerLine = 16
                for lineStart in stride(from: 0, to: outputData.count, by: bytesPerLine) {
                    let lineEnd = min(lineStart + bytesPerLine, outputData.count)
                    let lineData = outputData[lineStart..<lineEnd]
                    let hexLine = lineData.map { String(format: "%02x", $0) }.joined(separator: " ")
                    let offset = String(format: "%04x", lineStart)
                    print("\(offset) - \(hexLine)")
                }
                print(String(repeating: "=", count: 80) + "\n")

                return outputData
            } else {
                print("❌ Magic/Version incorrectos")
            }
        }

        return nil
    }
}
