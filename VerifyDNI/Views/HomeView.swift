// HomeView.swift
// VerifyDNI
// Pantalla principal: conexión, acceso QR y NFC, historial de escaneos.
// Sin NavigationStack — la navegación la gestiona MainTabView.

import SwiftUI

// MARK: - HomeView

struct HomeView: View {

    @StateObject private var viewModel = HomeViewModel()

    // Modales de escaneo
    @State private var showQRScanModal  = false
    @State private var showNFCScanModal = false

    // Resultado NFC → presenta ResultView
    @State private var showNFCResult:       Bool                     = false
    @State private var nfcVerificationResult: MiDNIVerificationResult? = nil

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#040D1A").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header custom
                headerView

                // Contenido principal
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        Spacer(minLength: 8)

                        // 1. Banner de conexión
                        connectionBanner

                        // 2. Card NFC — abre ScanModal modo NFC
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showNFCScanModal = true
                            }
                        } label: {
                            nfcCard
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(white: 0.3))
                                        .padding(14)
                                }
                        }
                        .buttonStyle(.plain)

                        // 3. Card QR — abre ScanModal modo QR
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showQRScanModal = true
                            }
                        } label: {
                            instructionsCard
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(white: 0.3))
                                        .padding(14)
                                }
                        }
                        .buttonStyle(.plain)

                        // 4. Footer último escaneo
                        lastScanFooter

                        Spacer(minLength: ScreenSize.isSmall ? 24 : 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, ScreenSize.isSmall ? 90 : 120)
                }
            }
        }
        .preferredColorScheme(.dark)
        // Sheet QR
        .sheet(isPresented: $showQRScanModal) {
            ScanModal(
                isPresented:  $showQRScanModal,
                mode:         .qr,
                homeViewModel: viewModel
            )
            .presentationDetents([.medium])
            .presentationCornerRadius(28)
            .presentationBackground(Color(hex: "#040D1A"))
        }
        // Sheet NFC
        .sheet(isPresented: $showNFCScanModal) {
            ScanModal(
                isPresented:  $showNFCScanModal,
                mode:         .nfc,
                homeViewModel: viewModel,
                onNFCResult:  { result in
                    viewModel.recordScan(result)
                    nfcVerificationResult = result
                    showNFCResult         = true
                }
            )
            .presentationDetents([.medium])
            .presentationCornerRadius(28)
            .presentationBackground(Color(hex: "#040D1A"))
        }
        // ResultView para resultado NFC
        .fullScreenCover(isPresented: $showNFCResult) {
            if let result = nfcVerificationResult {
                ResultView(
                    result:      result,
                    onScanAgain: {
                        showNFCResult    = false
                        nfcVerificationResult = nil
                        // Re-abre la modal NFC para un nuevo intento
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showNFCScanModal = true
                        }
                    },
                    onDismiss: {
                        showNFCResult         = false
                        nfcVerificationResult = nil
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            VerifyDNILogo(fontSize: 22)
            Spacer()
            connectionDot
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Connection Dot

    private var connectionDot: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 7, height: 7)
            Text(connectionLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(connectionColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(connectionColor.opacity(0.10)))
        .animation(.easeInOut(duration: 0.3), value: viewModel.connectionState)
    }

    private var connectionColor: Color {
        switch viewModel.connectionState {
        case .connected:    return Color(hex: "#4ade80")
        case .connecting:   return Color(hex: "#facc15")
        case .disconnected: return Color(hex: "#ef4444")
        }
    }

    private var connectionLabel: String {
        switch viewModel.connectionState {
        case .connected:    return "Conectado"
        case .connecting:   return "Conectando"
        case .disconnected: return "Sin conexión"
        }
    }

    // MARK: - Banner de conexión

    private var connectionBanner: some View {
        let config = BannerConfig(
            state: viewModel.connectionState,
            establishmentName: viewModel.establishmentName
        )
        return HStack(spacing: 12) {
            ZStack {
                if viewModel.connectionState == .connected {
                    PulsingDot(color: config.dotColor)
                } else {
                    Circle().fill(config.dotColor).frame(width: 10, height: 10)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(config.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(config.titleColor)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(config.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(config.subtitleColor)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if viewModel.connectionState == .disconnected {
                Button {
                    Task { await viewModel.refreshConnection() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#ef4444"))
                }
                .accessibilityLabel("Reconectar")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(config.backgroundColor)
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.connectionState)
    }

    // MARK: - Card QR

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cabecera con badge QR
            HStack(spacing: 12) {
                Image("midniapp")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Escanea el DNI digital")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Pide al cliente que abra MiDNI y muestre el código QR en pantalla")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                // Badge QR
                Text("QR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#60A5FA"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#1877FF").opacity(0.15))
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        Color(hex: "#1877FF").opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
            .padding(.bottom, 16)

            Divider().background(Color(white: 0.15)).padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: 1, 
                        text:   "El cliente abre MiDNI y genera su QR",
                        color:  Color(hex: "#60A5FA"))
                stepRow(number: 2, 
                        text:   "Tú pulsas el botón y apuntas la cámara",
                        color:  Color(hex: "#60A5FA"))
                stepRow(number: 3, 
                        text:   "Resultado en pantalla en menos de 2 segundos",
                        color:  Color(hex: "#60A5FA"))
            }
            .padding(.bottom, 14)

            Divider().background(Color(white: 0.15)).padding(.bottom, 12)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.4))
                    .padding(.top, 1)
                Text("El QR caduca a los 2 minutos. Si falla, pide al cliente uno nuevo.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#060f1e"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(hex: "#1877FF").opacity(0.18), lineWidth: 1)
                )
        )
    }

    // MARK: - Card NFC

    private var nfcCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cabecera con badge NFC
            HStack(spacing: 6) {
                Image(systemName: "wave.3.right.circle")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: "#60A5FA"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leer chip del DNI o NIE físico")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Acerca el documento físico al iPhone para leer los datos directamente del chip NFC")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                // Badge NFC
                Text("NFC")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#60A5FA"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#1877FF").opacity(0.15))
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        Color(hex: "#1877FF").opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
            .padding(.bottom, 16)

            Divider().background(Color(white: 0.15)).padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: 1,
                        text:   "Prepara el documento físico de identidad",
                        color:  Color(hex: "#60A5FA"))
                stepRow(number: 2,
                        text:   "Escanea el reverso del documento",
                        color:  Color(hex: "#60A5FA"))
                stepRow(number: 3,
                        text:   "Acerca el DNI al iPhone cuando se indique",
                        color:  Color(hex: "#60A5FA"))
            }
            .padding(.bottom, 14)

            Divider().background(Color(white: 0.15)).padding(.bottom, 12)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.4))
                    .padding(.top, 1)
                Text("Compatible con NIE y DNIe 3.0/4.0 (emitidos desde 2015)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#060f1e"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(hex: "#1877FF").opacity(0.18), lineWidth: 1)
                )
        )
    }

    // MARK: - Fila de paso numerado

    private func stepRow(
        number: Int,
        text:   String,
        color:  Color = Color(hex: "#1877FF")
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.8))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    // MARK: - Footer último escaneo

    private var lastScanFooter: some View {
        Group {
            if let scan = viewModel.lastScan {
                HStack(spacing: 6) {
                    Image(systemName: scan.wasValid
                          ? (scan.isExpired ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                          : "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(
                            scan.wasValid
                                ? (scan.isExpired ? Color(hex: "#f97316") : Color(hex: "#4ade80"))
                                : Color(hex: "#ef4444")
                        )
                    Text("Última verificación:")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.4))
                    Text(scan.statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(
                            scan.wasValid
                                ? (scan.isExpired ? Color(hex: "#f97316") : Color(hex: "#4ade80"))
                                : Color(hex: "#ef4444")
                        )
                    Text("·").foregroundColor(Color(white: 0.3))
                    TimelineView(.periodic(from: .now, by: 30)) { _ in
                        Text(scan.elapsedText)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.4))
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
            } else {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.3))
                    Text("Sin verificaciones hoy")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.3))
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - BannerConfig

private struct BannerConfig {
    let backgroundColor: Color
    let dotColor:        Color
    let titleColor:      Color
    let subtitleColor:   Color
    let title:           String
    let subtitle:        String

    init(state: WebSocketManager.ConnectionState, establishmentName: String) {
        switch state {
        case .connected:
            backgroundColor = Color(hex: "#0f2a0f")
            dotColor        = Color(hex: "#4ade80")
            titleColor      = Color(hex: "#4ade80")
            subtitleColor   = Color(hex: "#166534")
            title           = "Panel conectado"
            subtitle        = establishmentName
        case .connecting:
            backgroundColor = Color(hex: "#1a1200")
            dotColor        = Color(hex: "#facc15")
            titleColor      = Color(hex: "#facc15")
            subtitleColor   = Color(hex: "#713f12")
            title           = "Conectando..."
            subtitle        = "Estableciendo conexión"
        case .disconnected:
            backgroundColor = Color(hex: "#1a0a0a")
            dotColor        = Color(hex: "#ef4444")
            titleColor      = Color(hex: "#ef4444")
            subtitleColor   = Color(hex: "#7f1d1d")
            title           = "Panel no conectado"
            subtitle        = "Los datos no llegarán al ordenador"
        }
    }
}

// MARK: - PulsingDot

private struct PulsingDot: View {
    let color: Color
    @State private var scale:   CGFloat = 1.0
    @State private var opacity: Double  = 0.7

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(opacity * 0.4))
                .frame(width: 18, height: 18)
                .scaleEffect(scale)
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                scale   = 1.6
                opacity = 0.1
            }
        }
    }
}

// MARK: - Preview

#Preview { HomeView() }
