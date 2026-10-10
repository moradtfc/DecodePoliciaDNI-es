// NFCInputView.swift
// VerifyDNI
// Flujo en dos fases:
//   Fase 1 — Cámara escanea la zona MRZ del DNI automáticamente.
//   Fase 2 — NFC lee el chip usando la MRZ key calculada.

import SwiftUI

struct NFCInputView: View {

    @Binding var isPresented: Bool
    let onSuccess: (MiDNIVerificationResult) -> Void

    @StateObject private var viewModel = NFCViewModel()
    @State private var phase: Phase = .mrzScan

    // NFC reading phase state
    @State private var dniSweepOffset: CGFloat = -70
    @State private var nfcRingPulse: Bool = false

    private enum Phase {
        case mrzScan      // Fase 1: cámara leyendo MRZ
        case mrzConfirm   // MRZ detectado, listo para NFC
        case nfcReading   // Fase 2: NFC activo
    }

    var body: some View {
        ZStack {
            Color(hex: "#040D1A").ignoresSafeArea()

            switch phase {
            case .mrzScan:
                mrzScanPhase
            case .mrzConfirm:
                mrzConfirmPhase
            case .nfcReading:
                nfcReadingPhase
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    // MARK: - Fase 1: Escáner MRZ

    private var mrzScanPhase: some View {
        ZStack(alignment: .top) {
            // Cámara a pantalla completa
            MRZScannerView { scanResult in
                print("🟢 [NFCInputView] MRZ detectado")
                viewModel.processMRZResult(scanResult)
                withAnimation { phase = .mrzConfirm }
            }
            .ignoresSafeArea()

            // Overlay superior
            VStack(spacing: 0) {
                // Handle + cabecera
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(white: 0.5))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)

                    Text("Escanear DNI")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text("Apunta la cámara a las dos líneas\nde código al final del DNI")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#040D1A"), Color(hex: "#040D1A").opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                Spacer()

                // Guía visual MRZ y botón cancelar
                VStack(spacing: 16) {
                    // Marco guía
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(hex: "#1877FF"), lineWidth: 2)
                        .frame(height: 80)
                        .padding(.horizontal, 32)
                        .overlay(
                            VStack(spacing: 4) {
                                Text("ZONA MRZ")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#1877FF"))
                                Text("<<<<<<<<<<<<<<<<<<<<<<<<<<<")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color(hex: "#1877FF").opacity(0.6))
                                    .lineLimit(1)
                            }
                        )

                    HStack(spacing: 6) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#60A5FA"))
                        Text("Detección automática al enfocar")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#60A5FA"))
                    }

                    Button("Cancelar") { isPresented = false }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(white: 0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#040D1A").opacity(0), Color(hex: "#040D1A")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }
        }
        .onAppear { print("🔵 [NFCInputView] Fase 1: escáner MRZ activo") }
    }

    // MARK: - MRZ Confirmado

    private var mrzConfirmPhase: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(white: 0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 28)

            // Icono éxito MRZ
            ZStack {
                Circle()
                    .fill(Color(hex: "#166534").opacity(0.3))
                    .frame(width: 72, height: 72)
                Circle()
                    .strokeBorder(Color(hex: "#4ade80").opacity(0.4), lineWidth: 1)
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "#4ade80"))
            }
            .padding(.bottom, 20)

            // Título dinámico: DNI o TIE según lo que detectó el MRZ scanner
            let docTypeLabel: String = {
                if let nat = viewModel.scannedNationality {
                    return nat.uppercased() == "ESP" ? "DNI detectado" : "TIE detectado"
                }
                return "Documento detectado"
            }()
            Text(docTypeLabel)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 8)

            // Nota: el nombre NO se muestra aquí porque el OCR del MRZ puede fusionar
            // caracteres (ej. "JESUS<ALBERTO" → "JESUSCALBERTO"). Los datos correctos
            // con tildes y formato exacto se obtienen del chip NFC.
            Text("El nombre y datos completos se obtendrán del chip")
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.35))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            // Datos MRZ extraídos — permite verificar que el OCR fue correcto
            mrzDataView
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            let chipDocLabel = viewModel.scannedNationality.flatMap {
                $0.uppercased() == "ESP" ? "DNI" : "TIE"
            } ?? "documento"
            Text("Ahora acerca la parte trasera\ndel \(chipDocLabel) al iPhone para leer el chip")
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.5))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            // Instrucción NFC
            HStack(spacing: 12) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#60A5FA"))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Posición correcta")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Parte trasera superior del iPhone,\ncerca del módulo de cámara.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.45))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color(hex: "#1877FF").opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 28)

            // Botón leer chip NFC
            // NOTA: NO cambiamos phase aquí. La transición a .nfcReading ocurre
            // en .onChange(of: viewModel.nfcSessionStarted) cuando el hardware NFC
            // confirma que la sesión arrancó (requestPresentPassport). De este modo
            // si el NFC falla antes de iniciarse (hardware ocupado, Code=203) el
            // usuario permanece en esta pantalla y ve el error inline, sin pasar
            // por la pantalla azul de lectura.
            Button {
                guard !viewModel.isReading else { return }
                viewModel.nfcError = nil
                Task {
                    await viewModel.startNFCReading(
                        onSuccess: { result in
                            print("🟢 [NFCInputView] NFC onSuccess")
                            isPresented = false
                            onSuccess(result)
                        },
                        onError: { _ in
                            print("🔴 [NFCInputView] NFC onError")
                            dniSweepOffset = -70
                            phase = .mrzConfirm
                        }
                    )
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "wave.3.right.circle")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Leer chip NFC")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: ScreenSize.isSmall ? 48 : 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(hex: "#2D8FFF"), Color(hex: "#1877FF")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .shadow(color: Color(hex: "#1877FF").opacity(0.4), radius: 12, y: 6)
                )
            }
            .padding(.horizontal, 24)

            // Error inline si existe
            if let error = viewModel.nfcError {
                errorBanner(error: error)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button("Volver a escanear") {
                viewModel.nfcError = nil
                dniSweepOffset = -70  // reset animation for next reading attempt
                withAnimation { phase = .mrzScan }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color(white: 0.4))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .padding(.horizontal, 24)
            .padding(.top, 4)

            Button("Cancelar") { isPresented = false }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(white: 0.3))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.25), value: viewModel.nfcError != nil)
        // Cambiamos de fase solo cuando el hardware NFC confirma el arranque,
        // no cuando el usuario pulsa el botón. Esto evita la pantalla azul
        // cuando el NFC falla inmediatamente (System resource unavailable).
        .onChange(of: viewModel.nfcSessionStarted) { started in
            if started {
                withAnimation { phase = .nfcReading }
            }
        }
    }

    // MARK: - Fase 2: Leyendo NFC

    private var nfcReadingPhase: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Encabezado + barra de progreso ──────────────────────────
            VStack(spacing: 16) {
                Text(viewModel.nfcPhaseLabel)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.nfcPhaseLabel)

                // Barra de progreso
                nfcProgressBar
            }

            Spacer().frame(height: 28)

            // ── Diagrama animado ─────────────────────────────────────────
            // iPhone (back view) + DNI card sweeping up-down
            ZStack(alignment: .center) {
                // iPhone outline
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color(white: 0.3), lineWidth: 1.5)
                    .frame(width: 100, height: 190)

                // Camera bump (top-back)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 0.18))
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color(white: 0.3), lineWidth: 1)
                    )
                    .offset(y: -68)

                // NFC antenna zone (pulsing glow near top)
                ZStack {
                    Circle()
                        .fill(Color(hex: "#1877FF").opacity(nfcRingPulse ? 0.22 : 0.08))
                        .frame(width: 56, height: 56)
                        .scaleEffect(nfcRingPulse ? 1.18 : 1.0)
                    Circle()
                        .strokeBorder(Color(hex: "#60A5FA").opacity(0.5), lineWidth: 1)
                        .frame(width: 56, height: 56)
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#60A5FA"))
                }
                .offset(y: -42)
                .animation(
                    .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                    value: nfcRingPulse
                )

                // DNI card sweeping
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#1a3a6e"), Color(hex: "#0d2550")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color(hex: "#60A5FA").opacity(0.6), lineWidth: 1)
                        )
                    VStack(spacing: 2) {
                        let cardLabel = viewModel.scannedNationality.flatMap {
                            $0.uppercased() == "ESP" ? "DNI" : "TIE"
                        } ?? "DNI"
                        Text(cardLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "#60A5FA"))
                        Text("ESPAÑA")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(Color(white: 0.45))
                        // Chip indicator (NFC chip on front of DNI)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#fbbf24").opacity(0.7))
                            .frame(width: 18, height: 12)
                            .overlay(
                                HStack(spacing: 2) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 0.5)
                                            .fill(Color(hex: "#92400e").opacity(0.5))
                                            .frame(width: 3, height: 8)
                                    }
                                }
                            )
                    }
                }
                .offset(y: dniSweepOffset)
                .animation(
                    .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                    value: dniSweepOffset
                )

                // Arrow guide (right side)
                VStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: "#60A5FA").opacity(0.4 + Double(i) * 0.12))
                    }
                }
                .offset(x: 60)
            }
            .frame(width: 180, height: 200)

            Spacer().frame(height: 20)

            // ── Instrucción principal ────────────────────────────────────
            let nfcDocLabel = viewModel.scannedNationality.flatMap {
                $0.uppercased() == "ESP" ? "DNI" : "TIE"
            } ?? "DNI"
            Text("Desliza el \(nfcDocLabel) MUY lentamente\nde arriba a abajo por la parte trasera del iPhone")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)

            Spacer().frame(height: 14)

            // ── Consejo ──────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#facc15"))
                Text("El chip NFC del \(nfcDocLabel) está en la portada. Acerca ESA cara al iPhone.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#facc15").opacity(0.85))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(hex: "#facc15").opacity(0.07)))
            .padding(.horizontal, 28)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Reset and start animations
            dniSweepOffset = -70
            nfcRingPulse   = false

            // Brief delay so the view is fully laid out before animating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                nfcRingPulse   = true
                dniSweepOffset = 70
            }
        }
    }

    // MARK: - Barra de progreso NFC

    private var nfcProgressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 6)

                    // Relleno animado
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#2D8FFF"), Color(hex: "#60A5FA")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(6, geo.size.width * viewModel.nfcProgress),
                            height: 6
                        )
                        // Glow suave sobre el relleno
                        .shadow(color: Color(hex: "#60A5FA").opacity(0.55), radius: 6, y: 0)
                        .animation(.easeInOut(duration: 0.4), value: viewModel.nfcProgress)
                }
            }
            .frame(height: 6)

            // Etiquetas de porcentaje y estado
            HStack {
                Text(viewModel.nfcProgress >= 1.0
                     ? "Completado"
                     : viewModel.nfcProgress < 0.04
                       ? "Esperando chip..."
                       : "Leyendo datos del chip")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.4))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.nfcProgress)

                Spacer()

                Text(viewModel.nfcProgress < 0.04
                     ? ""
                     : "\(Int(viewModel.nfcProgress * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#60A5FA").opacity(0.8))
                    .animation(.easeInOut(duration: 0.4), value: viewModel.nfcProgress)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Datos MRZ extraídos (verificación visual)

    @ViewBuilder
    private var mrzDataView: some View {
        let doc = viewModel.scannedDocNum
        let dob = viewModel.scannedDOB
        let exp = viewModel.scannedExpiry
        let nat = viewModel.scannedNationality
        if !doc.isEmpty {
            let isTIE = nat.map { $0.uppercased() != "ESP" } ?? false

            VStack(spacing: 6) {
                // Badge de tipo de documento (DNI / TIE) si ya se detectó la nacionalidad
                if let nat {
                    HStack(spacing: 6) {
                        Image(systemName: isTIE ? "person.crop.rectangle.badge.plus" : "creditcard.fill")
                            .font(.system(size: 11))
                        Text(isTIE ? "TIE — Nacionalidad: \(nat)" : "DNI — Español")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(isTIE ? Color(hex: "#f97316") : Color(hex: "#4ade80"))
                    .padding(.bottom, 2)
                }

                // Para TIE: doc es el número de soporte de la tarjeta (campo 5A del MRZ),
                // NO el NIE real. El NIE (ej. Y1234567X) se extrae del chip NFC.
                // Para DNI: doc es el número de soporte (IDESP...), el número real también viene del chip.
                mrzRow(
                    icon: "creditcard",
                    label: isTIE ? "Nº Soporte TIE" : "Nº Soporte",
                    value: doc
                )

                if isTIE {
                    // Aviso explícito: el NIE viene del chip, no del MRZ
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#60A5FA").opacity(0.7))
                        Text("El NIE se leerá del chip NFC")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#60A5FA").opacity(0.7))
                        Spacer()
                    }
                }

                if !dob.isEmpty {
                    mrzRow(icon: "calendar", label: "F. Nacimiento",
                           value: formatMRZDate(dob))
                }
                if !exp.isEmpty {
                    mrzRow(icon: "calendar.badge.clock", label: "Caducidad",
                           value: formatMRZDate(exp))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isTIE
                                    ? Color(hex: "#f97316").opacity(0.25)
                                    : Color(hex: "#4ade80").opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
        }
    }

    private func mrzRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#60A5FA"))
                .frame(width: 16)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.45))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(white: 0.75))
        }
    }

    /// Convierte "yyMMdd" → "dd/MM/yy" para mostrar al usuario
    private func formatMRZDate(_ yymmdd: String) -> String {
        guard yymmdd.count == 6 else { return yymmdd }
        let yy = String(yymmdd.prefix(2))
        let mm = String(yymmdd.dropFirst(2).prefix(2))
        let dd = String(yymmdd.dropFirst(4))
        return "\(dd)/\(mm)/\(yy)"
    }

    // MARK: - Banner de error inline

    @ViewBuilder
    private func errorBanner(error: NFCViewModel.NFCReadError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#f87171"))
                Text(error.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#f87171"))
                Spacer()
                Button {
                    withAnimation { viewModel.nfcError = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(white: 0.4))
                }
            }
            Text(error.message)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.55))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#facc15"))
                Text(error.instruction)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#facc15"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#ef4444").opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(hex: "#ef4444").opacity(0.25), lineWidth: 1)
                )
        )
    }
}
