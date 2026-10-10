// MRZScanFrameView.swift
// VerifyDNI
// Marco de escaneo con esquinas redondeadas para ilustrar la captura del MRZ.

import SwiftUI

struct MRZScanFrameView: View {
    var cornerLength: CGFloat = 22
    var cornerRadius: CGFloat = 6
    var lineWidth: CGFloat    = 3
    var color: Color          = Color(hex: "#60A5FA")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Overlay oscuro
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: "#0A1628").opacity(0.55))

                // Línea de escaneo interna
                ScanLineView(height: h)
                    .clipped()

                // Esquinas
                Path { path in
                    // Top-left
                    path.move(to: CGPoint(x: 0, y: cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: cornerRadius))
                    path.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0),
                                      control: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: cornerLength, y: 0))

                    // Top-right
                    path.move(to: CGPoint(x: w - cornerLength, y: 0))
                    path.addLine(to: CGPoint(x: w - cornerRadius, y: 0))
                    path.addQuadCurve(to: CGPoint(x: w, y: cornerRadius),
                                      control: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: cornerLength))

                    // Bottom-right
                    path.move(to: CGPoint(x: w, y: h - cornerLength))
                    path.addLine(to: CGPoint(x: w, y: h - cornerRadius))
                    path.addQuadCurve(to: CGPoint(x: w - cornerRadius, y: h),
                                      control: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w - cornerLength, y: h))

                    // Bottom-left
                    path.move(to: CGPoint(x: cornerLength, y: h))
                    path.addLine(to: CGPoint(x: cornerRadius, y: h))
                    path.addQuadCurve(to: CGPoint(x: 0, y: h - cornerRadius),
                                      control: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h - cornerLength))
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .shadow(color: color.opacity(0.5), radius: 4)
            }
        }
    }
}
