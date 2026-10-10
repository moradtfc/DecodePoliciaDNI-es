import SwiftUI
import Foundation

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var hexValue: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&hexValue)

        let a, r, g, b: UInt64
        switch trimmed.count {
        case 3:  (a, r, g, b) = (255, (hexValue >> 8) * 17, (hexValue >> 4 & 0xF) * 17, (hexValue & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, hexValue >> 16, hexValue >> 8 & 0xFF, hexValue & 0xFF)
        case 8:  (a, r, g, b) = (hexValue >> 24, hexValue >> 16 & 0xFF, hexValue >> 8 & 0xFF, hexValue & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
