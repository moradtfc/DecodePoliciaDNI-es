// AdaptiveLayout.swift
// VerifyDNI — Utilidades de layout adaptativo para todos los iPhone soportados.
// SE 3ª gen (375×667) → iPhone 16 Pro Max (440×956)

import SwiftUI

// MARK: - ScreenSize

enum ScreenSize {
    case small    // SE / altura < 700 pt
    case medium   // estándar 700–899 pt
    case large    // Plus / Pro Max ≥ 900 pt

    /// Bounds de pantalla sin usar UIScreen.main (deprecated en iOS 26).
    /// Prioriza la escena activa en foreground; fallback a la primera disponible
    /// y, si no hay ninguna todavía (arranque muy temprano), a iPhone 14 estándar.
    private static func screenBounds() -> CGRect {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene  = scenes.first(where: { $0.activationState == .foregroundActive })
                  ?? scenes.first
        return scene?.screen.bounds
            ?? CGRect(x: 0, y: 0, width: 390, height: 844) // fallback iPhone 14
    }

    static var current: ScreenSize {
        let h = screenBounds().height
        if h < 700 { return .small  }
        if h < 900 { return .medium }
        return .large
    }

    static var isSmall: Bool    { current == .small  }
    static var isLarge: Bool    { current == .large  }
    static var height:  CGFloat { screenBounds().height }
    static var width:   CGFloat { screenBounds().width  }
}

// MARK: - CGFloat adaptativo

extension CGFloat {
    /// Escala completa por tamaño de pantalla.
    var adaptive: CGFloat {
        switch ScreenSize.current {
        case .small:  return self * 0.70
        case .medium: return self * 0.85
        case .large:  return self
        }
    }
    /// Reduce solo en pantallas pequeñas (SE).
    var adaptiveSmall: CGFloat {
        ScreenSize.isSmall ? self * 0.75 : self
    }
}

// MARK: - Fuentes y espaciados adaptativos

func adaptiveFontSize(_ base: CGFloat) -> CGFloat {
    switch ScreenSize.current {
    case .small:  return base * 0.82
    case .medium: return base * 0.92
    case .large:  return base
    }
}

func adaptiveSpacing(_ base: CGFloat) -> CGFloat {
    switch ScreenSize.current {
    case .small:  return max(4, base * 0.60)
    case .medium: return base * 0.85
    case .large:  return base
    }
}

// MARK: - Modificadores de View

extension View {

    // ── Padding adaptativo ─────────────────────────────────────────
    func adaptiveHPadding(_ base: CGFloat = 24) -> some View {
        self.padding(.horizontal, base.adaptiveSmall)
    }
    func adaptiveVPadding(_ base: CGFloat = 16) -> some View {
        self.padding(.vertical, base.adaptiveSmall)
    }

    // ── Altura de botones ──────────────────────────────────────────
    func adaptiveButtonHeight(_ base: CGFloat = 54) -> some View {
        self.frame(height: ScreenSize.isSmall ? 48 : base)
    }

    // ── Frame adaptativo ───────────────────────────────────────────
    func adaptiveFrame(width: CGFloat? = nil,
                       height: CGFloat? = nil) -> some View {
        self.frame(
            width:  width.map  { min($0, ScreenSize.width  - 48) },
            height: height.map { $0.adaptiveSmall }
        )
    }

    // ── Texto sin truncado ─────────────────────────────────────────
    /// Texto que se expande verticalmente en lugar de truncar.
    func noTruncation() -> some View {
        self
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    // ── Estilos de texto adaptativos ───────────────────────────────
    func adaptiveTitle(size: CGFloat = 22) -> some View {
        self
            .font(.system(size: adaptiveFontSize(size), weight: .bold))
            .minimumScaleFactor(0.75)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    func adaptiveDescription(size: CGFloat = 15) -> some View {
        self
            .font(.system(size: adaptiveFontSize(size)))
            .minimumScaleFactor(0.80)
            .lineLimit(nil)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    func adaptiveDataValue(size: CGFloat = 15) -> some View {
        self
            .font(.system(size: adaptiveFontSize(size), weight: .medium))
            .minimumScaleFactor(0.80)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Detección de safe area

struct SafeAreaInsetsKey: PreferenceKey {
    static var defaultValue = EdgeInsets()
    static func reduce(value: inout EdgeInsets,
                       nextValue: () -> EdgeInsets) { value = nextValue() }
}

// MARK: - Tab bar height environment

struct TabBarHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 80
}
extension EnvironmentValues {
    var tabBarHeight: CGFloat {
        get { self[TabBarHeightKey.self] }
        set { self[TabBarHeightKey.self] = newValue }
    }
}

// MARK: - DEBUG helpers

#if DEBUG
extension View {
    func debugTextBounds() -> some View {
        self.overlay(
            Rectangle()
                .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
        )
    }
}
#endif
