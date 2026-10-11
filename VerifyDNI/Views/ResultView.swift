// ResultView.swift
// VerifyDNI
//
// Pantalla de resultado de verificación MiDNI.
//   • isValid = true  → fondo verde (#052e16), datos completos del ciudadano
//   • isValid = false → fondo rojo (#450a0a), código de error (sin modificar)

import SwiftUI
import UIKit

// MARK: - Array uniqued helper

private extension Array where Element: Equatable {
    func uniqued() -> [Element] {
        reduce([]) { $0.contains($1) ? $0 : $0 + [$1] }
    }
}

// MARK: - ResultView

struct ResultView: View {

    let result: MiDNIVerificationResult
    let onScanAgain: () -> Void
    let onDismiss: () -> Void

    // MARK: - Estado local

    @State private var cardVisible = false
    @State private var sendState: SendState = .idle

    enum SendState { case idle, sending, sent, failed }

    // MARK: - Body

    var body: some View {
        if result.isValid {
            if isExpired {
                expiredBody
            } else {
                validBody
            }
        } else {
            invalidBody
        }
    }
}

// MARK: - Funciones auxiliares

private extension ResultView {

    /// Genera el texto a compartir/copiar con todos los datos excepto fotos
    func generateShareableText() -> String {
        var text = "=== VERIFICACIÓN DE IDENTIDAD ===\n\n"

        // Datos del documento
        if let number = result.documentNumber {
            text += "Número de Documento: \(number)\n"
        }
        if let name = result.name {
            text += "Nombres: \(name)\n"
        }
        if let surnames = result.surnames {
            text += "Apellidos: \(surnames)\n"
        }
        if let dateOfBirth = result.dateOfBirth {
            text += "Fecha de Nacimiento: \(dateOfBirth)\n"
        }
        if let gender = result.gender {
            text += "Sexo: \(gender == "M" ? "Masculino" : "Femenino")\n"
        }
        if let expiry = result.documentExpiry {
            text += "Fecha de Caducidad: \(expiry)\n"
        }

        // Datos de mayoría de edad
        if let isAdult = result.isAdult {
            text += "Mayor de Edad: \(isAdult ? "Sí" : "No")\n"
        }

        // Datos adicionales (QR completo)
        if let address = result.address {
            text += "Dirección: \(address)\n"
        }
        if let birthPlace = result.birthPlace {
            text += "Lugar de Nacimiento: \(birthPlace)\n"
        }
        if let nationality = result.nationality {
            text += "Nacionalidad: \(nationality)\n"
        }
        if let parents = result.parentsNames {
            text += "Padres: \(parents)\n"
        }

        // Datos NFC
        if let issueDate = result.issueDate {
            text += "Fecha de Expedición: \(issueDate)\n"
        }
        if let supportNumber = result.supportNumber {
            text += "Número de Soporte: \(supportNumber)\n"
        }

        // Información de verificación
        text += "\n--- INFORMACIÓN DE VERIFICACIÓN ---\n"
        text += "Tipo de Documento: \(result.documentTypeLabel)\n"
        text += "Método de Escaneo: \(result.scanMethod.uppercased())\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
        let validationDate = dateFormatter.string(from: result.verificationTimestamp)
        text += "Fecha de Validación: \(validationDate)\n"

        return text
    }
}

// MARK: - Vista válida

private extension ResultView {

    var validBody: some View {
        ZStack {
            Color(hex: "#052e16").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    heroSection
                        .padding(.top, 24)

                    identityCard
                        .opacity(cardVisible ? 1 : 0)
                        .offset(y: cardVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: cardVisible)

                    qrTypeBadge

                    sendButton

                    secondaryActions
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .onAppear { cardVisible = true }
    }

    // MARK: Hero

    var heroSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundColor(Color(hex: "#4ade80"))

            Text("\(result.documentTypeLabel) verificado")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            // Fuente — NFC (chip) o QR (MiDNI)
            let isNFC = result.issueDate != nil || result.signatureImageData != nil
            Text(isNFC ? "Policía Nacional · Chip NFC" : "Policía Nacional · MiDNI")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#86efac"))

            // Cuenta regresiva — se recalcula cada segundo
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let expiry = result.dataExpiryDateTime {
                    let seconds = Int(expiry.timeIntervalSince(context.date))
                    if seconds > 0 {
                        let color: Color = seconds > 60
                            ? Color(hex: "#4ade80")
                            : seconds > 30
                                ? Color(hex: "#facc15")
                                : Color(hex: "#ef4444")
                        Label("QR válido · expira en \(seconds)s",
                              systemImage: "clock")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(color)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: Tarjeta de identidad

    var identityCard: some View {
        VStack(spacing: 0) {
            // ── Cabecera: foto(s) + datos principales ────────────────────────
            HStack(alignment: .top, spacing: 14) {
                photoColumn
                mainDataStack
                Spacer(minLength: 0)
            }
            .padding(18)

            // ── Separador ────────────────────────────────────────────────────
            Color.white.opacity(0.08)
                .frame(height: 1)
                .padding(.horizontal, 18)

            // ── Grid de datos ─────────────────────────────────────────────────
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(gridItems, id: \.label) { item in
                    gridCell(label: item.label, value: item.value)
                }
            }
            .padding(18)
        }
        .background(Color.white.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // Columna izquierda: foto del ciudadano + firma (si existe)
    var photoColumn: some View {
        VStack(spacing: 8) {
            photoView
            if let sigData = result.signatureImageData,
               let sigImage = UIImage(data: sigData) {
                Image(uiImage: sigImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 78, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
    }

    // Foto del ciudadano (o placeholder si no hay datos)
    var photoView: some View {
        Group {
            if let photo = citizenPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 78, height: 98)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#1a1a2e"))
                    .frame(width: 78, height: 98)
                    .overlay(
                        Image(systemName: "person.crop.rectangle")
                            .font(.system(size: 26))
                            .foregroundColor(Color(white: 0.35))
                    )
            }
        }
    }

    // Nombre, número de documento, badges
    var mainDataStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Nombre completo
            Text(result.fullName ?? "Nombre no disponible")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.80)
                .fixedSize(horizontal: false, vertical: true)

            // Número de documento — etiqueta dinámica (DNI / TIE / Pasaporte)
            Label(
                "\(result.documentTypeLabel) · \(result.documentNumber ?? "—")",
                systemImage: "creditcard"
            )
            .font(.system(size: 13))
            .foregroundColor(Color(hex: "#86efac"))

            // Badge tipo de documento (TIE = naranja, Pasaporte = azul, DNI = verde)
            documentTypeBadge

            // Badge mayoría de edad
            if let adult = result.isAdult {
                Text(adult ? "Mayor de edad ✓" : "Menor de edad")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(adult ? Color(hex: "#052e16") : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(adult ? Color(hex: "#4ade80") : Color(hex: "#ef4444"))
                    .clipShape(Capsule())
            }

            // Sexo
            if let gender = result.gender {
                let genderLabel = gender.uppercased() == "F" ? "Mujer" : "Hombre"
                Label(genderLabel, systemImage: "person")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.6))
            }
        }
    }

    // Badge colorido que indica DNI / TIE / Pasaporte
    @ViewBuilder
    var documentTypeBadge: some View {
        let label = result.documentTypeLabel
        let (bgColor, fgColor): (Color, Color) = {
            switch label {
            case "TIE":       return (Color(hex: "#f97316"), .white)   // naranja
            case "Pasaporte": return (Color(hex: "#3b82f6"), .white)   // azul
            default:          return (Color(hex: "#166534"), Color(hex: "#4ade80")) // verde oscuro
            }
        }()
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(fgColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bgColor)
            .clipShape(Capsule())
    }

    // Celda individual del grid
    func gridCell(label: String, value: String) -> some View {
        let isPermanent = value == "Sin caducidad"
        return VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(white: 0.45))
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(size: ScreenSize.isSmall ? 12 : 14,
                              weight: isPermanent ? .semibold : .medium))
                .foregroundColor(isPermanent ? Color(hex: "#4ade80") : .white)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.80)
        }
    }

    // MARK: Badge tipo de lectura (NFC chip o QR MiDNI)

    var qrTypeBadge: some View {
        let isNFC = result.issueDate != nil || result.signatureImageData != nil
        let (icon, label): (String, String) = {
            if isNFC {
                return ("antenna.radiowaves.left.and.right", "Chip NFC · \(result.documentTypeLabel) completo")
            }
            switch result.qrType {
            case .complete: return ("checkmark.shield", "QR · DNI completo")
            case .simple:   return ("idcard", "QR · DNI simple")
            case .age:      return ("person.crop.circle", "QR · Verificación de edad")
            case .none:     return ("doc.text.magnifyingglass", "Verificación")
            }
        }()

        return Label(label, systemImage: icon)
            .font(.system(size: 12))
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    // MARK: Botón enviar

    var sendButton: some View {
        Button {
            let textToShare = generateShareableText()
            let activityVC = UIActivityViewController(
                activityItems: [textToShare],
                applicationActivities: nil
            )

            // Excluir opciones no necesarias
            activityVC.excludedActivityTypes = [
                .print,
                .saveToPCMark,
                .addToReadingList
            ]

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityVC, animated: true)
            }
        } label: {
            let btnH: CGFloat = ScreenSize.isSmall ? 48 : 54
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Compartir datos")
                    .font(.system(size: 16, weight: .semibold))
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                    .allowsTightening(true)
            }
            .foregroundColor(Color(hex: "#052e16"))
            .frame(maxWidth: .infinity)
            .frame(height: btnH)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: Acciones secundarias

    var secondaryActions: some View {
        HStack(spacing: 12) {
            Button {
                let textToShare = generateShareableText()
                UIPasteboard.general.string = textToShare
            } label: {
                Label("Copiar datos", systemImage: "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }

            Button { onDismiss() } label: {
                Label("Cerrar", systemImage: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Vista caducada

private extension ResultView {

    // Comprueba si la fecha de caducidad del documento ya pasó.
    // DNI permanente ("01-01-9999") → DateFormatter parsea year=9999,
    // que es futuro → date < today = false → nunca marcado como caducado. ✓
    var isExpired: Bool {
        guard let expiry = result.documentExpiry else { return false }
        let fmt = DateFormatter()
        fmt.dateFormat = "dd-MM-yyyy"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        guard let date = fmt.date(from: expiry) else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }

    // Paleta de colores para la vista caducada (rojo, espejo de la paleta verde válida)
    var expiredAccent: Color     { Color(hex: "#f87171") }   // rojo-400
    var expiredMuted: Color      { Color(hex: "#fca5a5") }   // rojo-300
    var expiredBackground: Color { Color(hex: "#2d0808") }   // rojo muy oscuro

    var expiredBody: some View {
        ZStack {
            expiredBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    expiredHeroSection
                        .padding(.top, 24)

                    expiredWarningBanner

                    expiredIdentityCard
                        .opacity(cardVisible ? 1 : 0)
                        .offset(y: cardVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: cardVisible)

                    expiredSecondaryActions
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .onAppear { cardVisible = true }
    }

    // MARK: Hero caducado

    var expiredHeroSection: some View {
        VStack(spacing: 6) {
            // Icono X en rojo, mismo tamaño que el checkmark de la vista válida
            ZStack {
                Circle()
                    .fill(expiredAccent.opacity(0.12))
                    .frame(width: 80, height: 80)
                Circle()
                    .strokeBorder(expiredAccent.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 80, height: 80)
                Image(systemName: "xmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundColor(expiredAccent)
            }

            Text("Documento caducado")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            let isNFC = result.issueDate != nil || result.signatureImageData != nil
            Text(isNFC ? "Policía Nacional · Chip NFC" : "Policía Nacional · MiDNI")
                .font(.system(size: 13))
                .foregroundColor(expiredMuted)
        }
        .padding(.bottom, 4)
    }

    // MARK: Banner de alerta de caducidad

    var expiredWarningBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundColor(expiredAccent)

            VStack(alignment: .leading, spacing: 3) {
                Text("Este documento no es válido")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(expiredAccent)
                Text("La fecha de caducidad ha vencido. No puede utilizarse como documento de identificación.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(expiredAccent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(expiredAccent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: Tarjeta de identidad (caducada)
    // Misma estructura que `identityCard` pero con bordes/colores rojos
    // y la celda de Caducidad resaltada en rojo.

    var expiredIdentityCard: some View {
        VStack(spacing: 0) {
            // ── Cabecera: foto + datos ────────────────────────────────────
            HStack(alignment: .top, spacing: 14) {
                // Columna izquierda: foto con franja CADUCADO + firma (si existe)
                // La franja va DENTRO del ZStack de la foto para que quede siempre
                // en la parte inferior de la imagen, independientemente de la firma.
                VStack(spacing: 8) {
                    ZStack(alignment: .bottom) {
                        photoView   // solo la foto, sin la firma

                        // Franja "CADUCADO" pegada al borde inferior de la foto
                        Text("CADUCADO")
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(.white)
                            .tracking(0.5)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity)
                            .background(expiredAccent.opacity(0.88))
                            .clipShape(
                                UnevenRoundedRectangle(
                                    bottomLeadingRadius: 10,
                                    bottomTrailingRadius: 10
                                )
                            )
                    }

                    // Firma (si existe) debajo de la foto, igual que en photoColumn
                    if let sigData = result.signatureImageData,
                       let sigImage = UIImage(data: sigData) {
                        Image(uiImage: sigImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 78, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                }
                .frame(width: 78)

                expiredMainDataStack
                Spacer(minLength: 0)
            }
            .padding(18)

            Color.white.opacity(0.08)
                .frame(height: 1)
                .padding(.horizontal, 18)

            // ── Grid con Caducidad resaltada ───────────────────────────────
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(expiredGridItems, id: \.label) { item in
                    if item.label == "Caducidad" {
                        expiredGridCell(label: item.label, value: item.value)
                    } else {
                        gridCell(label: item.label, value: item.value)
                    }
                }
            }
            .padding(18)
        }
        .background(expiredAccent.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(expiredAccent.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // Datos principales en rojo para la tarjeta caducada
    var expiredMainDataStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.fullName ?? "Nombre no disponible")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.80)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                "\(result.documentTypeLabel) · \(result.documentNumber ?? "—")",
                systemImage: "creditcard"
            )
            .font(.system(size: 13))
            .foregroundColor(expiredMuted)

            // Badge tipo de documento (mismo que válido pero borde rojo)
            documentTypeBadge

            if let adult = result.isAdult {
                Text(adult ? "Mayor de edad ✓" : "Menor de edad")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(adult ? Color(hex: "#052e16") : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(adult ? Color(hex: "#4ade80") : Color(hex: "#ef4444"))
                    .clipShape(Capsule())
            }

            if let gender = result.gender {
                let genderLabel = gender.uppercased() == "F" ? "Mujer" : "Hombre"
                Label(genderLabel, systemImage: "person")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.6))
            }
        }
    }

    // Celda de caducidad con fondo rojo tenue
    func expiredGridCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(expiredAccent.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(size: ScreenSize.isSmall ? 12 : 14,
                              weight: .bold))
                .foregroundColor(expiredAccent)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.80)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(expiredAccent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // Grid igual que el válido pero reutilizando el mismo helper
    var expiredGridItems: [GridDataItem] { gridItems }

    // MARK: Acciones (caducado)

    var expiredSecondaryActions: some View {
        VStack(spacing: 12) {
            // Botón principal: nuevo escaneo (más prominente que en la vista válida)
            Button { onScanAgain() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Escanear otro documento")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(hex: "#1877FF"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Botón secundario: cerrar
            Button { onDismiss() } label: {
                Text("Cerrar")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(white: 0.45))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Vista inválida

private extension ResultView {

    var invalidBody: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Icono + títulos ───────────────────────────────────────────
                VStack(spacing: 16) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(Color(hex: "#ef4444"))

                    Text("Verificación inválida")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    if let name = result.fullName {
                        Text(name)
                            .font(.system(size: 16))
                            .foregroundColor(Color(white: 0.6))
                    }
                }

                // ── Descripción del error ─────────────────────────────────────
                if let error = result.errorType {
                    VStack(spacing: 10) {
                        Text(error.errorDescription ?? error.errorCode)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "#ef4444"))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(error.userInstruction)
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.5))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                }

                Spacer()

                // ── Botones ───────────────────────────────────────────────────
                VStack(spacing: 12) {
                    Button { onScanAgain() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Escanear de nuevo")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "#1877FF"))
                        .cornerRadius(12)
                    }

                    Button { onDismiss() } label: {
                        Text("Volver al inicio")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(white: 0.14))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Computed helpers

private extension ResultView {

    // Foto del ciudadano — solo en memoria, nunca en disco
    var citizenPhoto: UIImage? {
        guard let data = result.thumbnailImageData else { return nil }
        return UIImage(data: data)
    }

    // Código ISO 3166-1 alpha-3 → nombre en español
    var nationalityName: String {
        guard let code = result.nationality else { return "—" }
        let isoMap: [String: String] = [
            "ESP": "España",      "FRA": "Francia",          "DEU": "Alemania",
            "ITA": "Italia",      "PRT": "Portugal",         "GBR": "Reino Unido",
            "USA": "Estados Unidos", "MEX": "México",        "ARG": "Argentina",
            "COL": "Colombia",    "VEN": "Venezuela",        "MAR": "Marruecos",
            "ROU": "Rumanía",     "CHN": "China",            "ECU": "Ecuador",
            "BOL": "Bolivia",     "PER": "Perú",             "DOM": "República Dominicana",
            "UKR": "Ucrania",     "PAK": "Pakistán"
        ]
        return isoMap[code.uppercased()] ?? code
    }

    // "DD-MM-YYYY" → "1 oct 1978"
    // "DD-MM-9999" → "Sin caducidad" (DNI permanente para ≥ 70 años)
    func formatDate(_ dateString: String?) -> String {
        guard let dateString else { return "—" }
        let input = DateFormatter()
        input.dateFormat = "dd-MM-yyyy"
        input.locale = Locale(identifier: "es_ES")
        guard let date = input.date(from: dateString) else { return dateString }
        // El DNI permanente se almacena con año 9999 en el chip (DGP).
        // DateFormatter lo parsea correctamente; detectamos year ≥ 9000 → "Sin caducidad".
        if Calendar.current.component(.year, from: date) >= 9000 {
            return "Sin caducidad"
        }
        let output = DateFormatter()
        output.dateFormat = "d MMM yyyy"
        output.locale = Locale(identifier: "es_ES")
        return output.string(from: date)
    }

    // "DANIEL / PILAR" → (father: "DANIEL", mother: "PILAR")
    var parents: (father: String?, mother: String?) {
        guard let raw = result.parentsNames else { return (nil, nil) }
        let parts = raw.components(separatedBy: " / ")
        return (
            parts.indices.contains(0)
                ? parts[0].trimmingCharacters(in: .whitespaces)
                : nil,
            parts.indices.contains(1)
                ? parts[1].trimmingCharacters(in: .whitespaces)
                : nil
        )
    }

    // Dirección completa — elimina duplicados
    var fullAddress: String {
        [result.address]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .uniqued()
            .joined(separator: ", ")
    }

    // Lugar de nacimiento — combina líneas y elimina duplicados
    var birthPlaceDisplay: String {
        let val = [result.birthPlaceLine1, result.birthPlaceLine2, result.birthPlaceLine3]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .uniqued()
            .joined(separator: ", ")
        return val.isEmpty ? "—" : val
    }

    // Items del grid — solo incluye padre/madre/soporte si no son nil
    struct GridDataItem: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    var gridItems: [GridDataItem] {
        let expiryDisplay = formatDate(result.documentExpiry)
        var items: [GridDataItem] = [
            .init(label: "Nacimiento",    value: formatDate(result.dateOfBirth)),
            .init(label: "Caducidad",     value: expiryDisplay)
        ]
        // Fecha de expedición — solo disponible por NFC
        if let issue = result.issueDate {
            items.append(.init(label: "Expedición", value: formatDate(issue)))
        }
        items.append(contentsOf: [
            .init(label: "Nacionalidad",  value: nationalityName),
            .init(label: "Lugar de nac.", value: birthPlaceDisplay)
        ])
        if !fullAddress.isEmpty {
            items.append(.init(label: "Domicilio", value: fullAddress))
        }
        if let father = parents.father {
            items.append(.init(label: "Padre", value: father))
        }
        if let mother = parents.mother {
            items.append(.init(label: "Madre", value: mother))
        }
        if let support = result.supportNumber {
            items.append(.init(label: "Nº soporte", value: support))
        }
        return items
    }
}
