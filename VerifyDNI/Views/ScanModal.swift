// ScanModal.swift
// VerifyDNI
// Modal de confirmación previa al escaneo — soporta modo QR y modo NFC.
// El diseño estructural es idéntico en ambos modos; solo varían textos,
// icono, color del recordatorio y acción del botón principal.

import SwiftUI

// MARK: - ScanMode

enum ScanMode {
    case qr   // flujo QR MiDNI existente
    case nfc  // flujo NFC chip del DNI físico
}

// MARK: - ScanModal

struct ScanModal: View {

    @Binding var isPresented: Bool
    /// Modo de verificación. Por defecto .qr para no romper código existente.
    var mode: ScanMode = .qr
    /// ViewModel compartido con HomeView para registrar el resultado del escaneo QR.
    @ObservedObject var homeViewModel: HomeViewModel
    /// Callback invocado cuando la lectura NFC completa con éxito.
    var onNFCResult: ((MiDNIVerificationResult) -> Void)?

    @State private var showScanner      = false
    @State private var showNFCInput     = false
    @State private var isPreparingAction = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(white: 0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 24)

            // Icono central
            modeIcon
                .padding(.bottom, 20)

            // Título
            Text(mode == .qr
                 ? NSLocalizedString("scan_modal.qr.title", comment: "")
                 : NSLocalizedString("scan_modal.nfc.title", comment: ""))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.80)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            // Descripción
            Text(modeDescription)
                .font(.system(size: 15))
                .foregroundColor(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            // Recordatorio
            reminderView
                .padding(.bottom, 32)

            // Botón principal
            mainButton

            // Cancelar
            Button {
                isPresented = false
            } label: {
                Text(NSLocalizedString("scan_modal.cancel", comment: ""))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(white: 0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#040D1A"))
        // QR → abre ScannerView en fullScreenCover
        .fullScreenCover(isPresented: $showScanner) {
            ScannerView(homeViewModel: homeViewModel)
        }
        // NFC → fullScreenCover para evitar sheet-within-sheet y que el sistema NFC funcione correctamente
        .fullScreenCover(isPresented: $showNFCInput) {
            NFCInputView(
                isPresented: $showNFCInput,
                onSuccess: { result in
                    showNFCInput = false
                    isPresented  = false
                    onNFCResult?(result)
                }
            )
            .background(Color(hex: "#040D1A"))
        }
    }

    // MARK: - Icono central

    private var modeIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor.opacity(0.10))
                .frame(width: 72, height: 72)
            Circle()
                .strokeBorder(iconBackgroundColor.opacity(0.3), lineWidth: 1)
                .frame(width: 72, height: 72)
            Image(systemName: mode == .qr
                  ? "qrcode.viewfinder"
                  : "wave.3.right.circle.fill")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(Color(hex: "#60A5FA"))
        }
    }

    private var iconBackgroundColor: Color {
        mode == .qr ? Color(hex: "#1877FF") : Color(hex: "#0F4C81")
    }

    // MARK: - Textos adaptativos

    private var modeDescription: String {
        mode == .qr
            ? NSLocalizedString("scan_modal.qr.description", comment: "")
            : NSLocalizedString("scan_modal.nfc.description", comment: "")
    }

    // MARK: - Recordatorio

    private var reminderView: some View {
        HStack(spacing: 6) {
            Image(systemName: mode == .qr ? "clock" : "iphone.radiowaves.left.and.right")
                .font(.system(size: 12))
                .foregroundColor(reminderColor)
            Text(mode == .qr
                 ? NSLocalizedString("scan_modal.qr.reminder", comment: "")
                 : NSLocalizedString("scan_modal.nfc.reminder", comment: ""))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(reminderColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(reminderColor.opacity(0.08)))
    }

    private var reminderColor: Color {
        mode == .qr ? Color(hex: "#facc15") : Color(hex: "#60A5FA")
    }

    // MARK: - Botón principal

    private var mainButton: some View {
        Button {
            guard !isPreparingAction else { return }
            if mode == .qr {
                isPreparingAction = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    showScanner        = true
                    isPreparingAction  = false
                }
            } else {
                showNFCInput = true
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(buttonGradient)
                    .overlay(nfcButtonBorder)
                    .shadow(color: Color(hex: "#1877FF").opacity(0.4), radius: 12, y: 6)

                if isPreparingAction {
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.85)
                        Text(mode == .qr 
                             ? NSLocalizedString("scan_modal.qr.preparing", comment: "")
                             : NSLocalizedString("scan_modal.nfc.preparing", comment: ""))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: mode == .qr
                              ? "qrcode.viewfinder"
                              : "wave.3.right.circle")
                            .font(.system(size: 18, weight: .semibold))
                        Text(mode == .qr 
                             ? NSLocalizedString("scan_modal.qr.button", comment: "")
                             : NSLocalizedString("scan_modal.nfc.button", comment: ""))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: ScreenSize.isSmall ? 48 : 54)
        }
        .disabled(isPreparingAction)
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: isPreparingAction)
    }

    private var buttonGradient: AnyShapeStyle {
        if mode == .qr {
            AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "#2D8FFF"), Color(hex: "#1877FF")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        } else {
            AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "#0F4C81"), Color(hex: "#0A3260")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        }
    }

    @ViewBuilder
    private var nfcButtonBorder: some View {
        if mode == .nfc {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "#1877FF").opacity(0.4), lineWidth: 1)
        } else {
            EmptyView()
        }
    }
}
