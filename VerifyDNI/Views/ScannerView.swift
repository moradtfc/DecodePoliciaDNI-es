// ScannerView.swift
// VerifyDNI
//
// Pantalla de escaneo QR con ML Kit Barcode Scanning.
// Presentada como sheet desde HomeView.
//
// IMPORTANTE: requiere los paquetes ML Kit vía SPM o CocoaPods:
//   SPM  → https://github.com/google-ml-sdk/swift-package
//           Products: MLKitBarcodeScanning, MLKitVision
//   Pod  → pod 'GoogleMLKit/BarcodeScanning'

import SwiftUI
import AVFoundation
import MLKitBarcodeScanning
import MLKitVision

// MARK: - ScannerView

struct ScannerView: View {

    @StateObject private var viewModel = ScannerViewModel()
    @ObservedObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    // Estado de permiso de cámara
    @State private var cameraPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch cameraPermission {
                case .authorized:
                    cameraContent

                case .denied, .restricted:
                    cameraPermissionDeniedView

                default:
                    // .notDetermined — se solicita en .task
                    Color.black.ignoresSafeArea()
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
            }
            .navigationBarHidden(true)
            // Navegar a ResultView cuando el escaneo termina
            .navigationDestination(
                isPresented: Binding(
                    get: { if case .done = viewModel.scanState { return true }; return false },
                    set: { if !$0 { viewModel.resetScanner() } }
                )
            ) {
                if case .done(let result) = viewModel.scanState {
                    ResultView(
                        result: result,
                        onScanAgain: {
                            viewModel.resetScanner()
                        },
                        onDismiss: {
                            homeViewModel.recordScan(result)
                            dismiss()
                        }
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // Solicitar permiso de cámara si todavía no se ha determinado.
            if cameraPermission == .notDetermined {
                let status = await AVCaptureDevice.requestAccess(for: .video)
                cameraPermission = status ? .authorized : .denied
            }
        }
    }

    // MARK: - Contenido de cámara

    private var cameraContent: some View {
        ZStack {
            // ── Preview de cámara ─────────────────────────────────────────
            BarcodeScannerRepresentable(
                onBarcodeDetected: { data in
                    Task { await viewModel.processQRData(data) }
                },
                isActivelyScanning: viewModel.isActivelyScanning
            )
            .ignoresSafeArea()

            // ── Overlay oscuro con recorte central ────────────────────────
            ScannerDimmingOverlay(frameSize: 240)

            // ── Guías del marco + línea animada ───────────────────────────
            ScanFrameOverlay(
                frameSize: 240,
                scanState: viewModel.scanState
            )

            // ── Barra superior ────────────────────────────────────────────
            VStack {
                topBar
                Spacer()
                bottomControls
            }
        }
    }

    // MARK: - Barra superior

    private var topBar: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea(edges: .top)
                .frame(height: 56)

            Text("Escanear DNI")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
    }

    // MARK: - Controles inferiores

    private var bottomControls: some View {
        HStack {
            // Cancelar
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Cancelar")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.15))
                .cornerRadius(24)
            }

            Spacer()

            // Linterna
            Button {
                viewModel.toggleTorch()
            } label: {
                Image(systemName: viewModel.torchOn
                      ? "flashlight.on.fill"
                      : "flashlight.off.fill")
                    .font(.system(size: 22))
                    .foregroundColor(viewModel.torchOn ? Color(hex: "#facc15") : .white)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .accessibilityLabel(viewModel.torchOn ? "Apagar linterna" : "Encender linterna")
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
    }

    // MARK: - Vista permiso denegado

    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 52))
                .foregroundColor(Color(white: 0.4))

            Text("Cámara no disponible")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("VerifyDNI necesita acceso a la cámara\npara escanear los QR del DNI digital.")
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.5))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                UIApplication.shared.open(
                    URL(string: UIApplication.openSettingsURLString)!
                )
            } label: {
                Text("Abrir Ajustes")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "#1877FF"))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            Button("Cancelar") { dismiss() }
                .foregroundColor(Color(white: 0.5))
                .font(.system(size: 15))
        }
        .padding(32)
    }
}

// MARK: - ScannerDimmingOverlay

/// Capa semitransparente que oscurece toda la pantalla excepto el marco de escaneo.
private struct ScannerDimmingOverlay: View {
    let frameSize: CGFloat

    var body: some View {
        GeometryReader { geo in
            let frameRect = CGRect(
                x: (geo.size.width  - frameSize) / 2,
                y: (geo.size.height - frameSize) / 2,
                width: frameSize,
                height: frameSize
            )
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .mask(
                    // Usamos even-odd fill rule para crear el "agujero".
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: geo.size))
                        path.addRoundedRect(
                            in: frameRect,
                            cornerSize: CGSize(width: 8, height: 8)
                        )
                    }
                    .fill(style: FillStyle(eoFill: true))
                )
        }
        .ignoresSafeArea()
    }
}

// MARK: - ScanFrameOverlay

/// Marco de guías de esquina + línea de escaneo animada + estado de proceso.
private struct ScanFrameOverlay: View {
    let frameSize: CGFloat
    let scanState: ScannerViewModel.ScanState

    @State private var scanLineOffset: CGFloat = 0

    private var isProcessing: Bool {
        if case .processing = scanState { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                // ── Esquinas del marco ────────────────────────────────────
                ScanCornerGuides(size: frameSize)

                // ── Línea de escaneo (solo cuando scanning) ───────────────
                if case .scanning = scanState {
                    scanLine
                }

                // ── Indicador de proceso ──────────────────────────────────
                if isProcessing {
                    processingOverlay
                }
            }
            .frame(width: frameSize, height: frameSize)

            // ── Texto de ayuda ────────────────────────────────────────────
            if case .scanning = scanState {
                Text("Apunta al QR MiDNI del cliente")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 1)
            } else if isProcessing {
                Text("Verificando...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#1877FF"))
            }

            Spacer()
        }
        .onAppear { animateScanLine() }
    }

    // MARK: Línea de escaneo

    private var scanLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#1877FF").opacity(0),
                        Color(hex: "#1877FF"),
                        Color(hex: "#1877FF").opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .offset(y: scanLineOffset - frameSize / 2)
    }

    private func animateScanLine() {
        scanLineOffset = 0
        withAnimation(
            .linear(duration: 2.0)
            .repeatForever(autoreverses: false)
        ) {
            scanLineOffset = frameSize
        }
    }

    // MARK: Overlay de proceso

    private var processingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .frame(width: 90, height: 90)

            VStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#1877FF")))
                    .scaleEffect(1.3)
                Text("...")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.6))
            }
        }
    }
}

// MARK: - ScanCornerGuides

/// Las 4 esquinas en L del marco de encuadre.
private struct ScanCornerGuides: View {
    let size: CGFloat
    private let armLength: CGFloat = 30
    private let lineWidth: CGFloat = 3
    private let cornerRadius: CGFloat = 4

    var body: some View {
        Canvas { context, _ in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            var path = Path()

            // Top-left
            path.move(to:    CGPoint(x: rect.minX, y: rect.minY + armLength))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + armLength, y: rect.minY))

            // Top-right
            path.move(to:    CGPoint(x: rect.maxX - armLength, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius, startAngle: .degrees(270), endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + armLength))

            // Bottom-right
            path.move(to:    CGPoint(x: rect.maxX, y: rect.maxY - armLength))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX - armLength, y: rect.maxY))

            // Bottom-left
            path.move(to:    CGPoint(x: rect.minX + armLength, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - armLength))

            context.stroke(
                path,
                with: .color(Color(hex: "#1877FF")),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - BarcodeScannerRepresentable

struct BarcodeScannerRepresentable: UIViewControllerRepresentable {

    let onBarcodeDetected: (Data) -> Void
    /// Cuando es `false` (p.ej. durante `.processing` o `.done`),
    /// el VC pausa el procesamiento de frames.
    let isActivelyScanning: Bool

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let vc = BarcodeScannerViewController()
        vc.onBarcodeDetected = onBarcodeDetected
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController,
                                context: Context) {
        // Cuando ScannerViewModel llama resetScanner(), isActivelyScanning vuelve a true
        // y el VC reanuda el procesamiento de frames.
        if isActivelyScanning {
            uiViewController.resetProcessingFlag()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator: NSObject {}
}

// MARK: - BarcodeScannerViewController

final class BarcodeScannerViewController: UIViewController,
                                          AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: Interface

    var onBarcodeDetected: ((Data) -> Void)?

    /// Llámalo desde `updateUIViewController` cuando `isActivelyScanning` vuelve a `true`.
    func resetProcessingFlag() {
        isProcessingFrame = false
    }

    // MARK: Privado

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private let barcodeScanner: BarcodeScanner = {
        let options = BarcodeScannerOptions(formats: .qrCode)
        return BarcodeScanner.barcodeScanner(options: options)
    }()

    /// Evita procesar múltiples frames simultáneamente.
    private var isProcessingFrame = false

    // MARK: - Ciclo de vida

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    // MARK: - Configuración de cámara

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720

        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ),
            let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        guard session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(
            self,
            queue: DispatchQueue(label: "es.verifydni.scanner.framequeue", qos: .userInitiated)
        )
        output.alwaysDiscardsLateVideoFrames = true

        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)

        captureSession = session
        previewLayer  = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard !isProcessingFrame else { return }

        let visionImage = VisionImage(buffer: sampleBuffer)
        visionImage.orientation = imageOrientation()

        barcodeScanner.process(visionImage) { [weak self] barcodes, error in
            guard
                let self,
                error == nil,
                let barcode = barcodes?.first,
                let rawData = barcode.rawData,     // CRÍTICO: rawData, NUNCA rawValue
                !rawData.isEmpty
            else { return }

            self.isProcessingFrame = true   // bloquear hasta que el ViewModel haga reset

            DispatchQueue.main.async {
                self.onBarcodeDetected?(rawData)
            }
        }
    }

    // MARK: - Orientación

    private func imageOrientation() -> UIImage.Orientation {
        switch UIDevice.current.orientation {
        case .portrait:           return .up
        case .portraitUpsideDown: return .down
        case .landscapeLeft:      return .right
        case .landscapeRight:     return .left
        default:                  return .up
        }
    }
}

// MARK: - Preview

#Preview {
    ScannerView(homeViewModel: HomeViewModel())
}
