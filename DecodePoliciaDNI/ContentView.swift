//
//  ContentView.swift
//  DecodePoliciaDNI
//
//  Created by Jesus Mora on 1/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showScanner = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Icono principal
                Image(systemName: "qrcode.viewfinder")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundColor(.blue)

                // Título
                Text("Escáner miDNI")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Descripción
                Text("Escanea el código QR de tu DNI digital español para verificar la información")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Botón para abrir el escáner
                Button(action: {
                    print("🚀 Abriendo escáner de QR...")
                    showScanner = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Escanear código QR")
                            .fontWeight(.semibold)
                    }
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(15)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding(.top, 60)
            .navigationTitle("miDNI Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showScanner) {
                QRScannerView()
            }
        }
    }
}

#Preview {
    ContentView()
}
