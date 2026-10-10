// MainTabView.swift
// VerifyDNI
// Vista raíz principal.

import SwiftUI

struct MainTabView: View {

    @EnvironmentObject private var wsManager: WebSocketManager

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "#040D1A").ignoresSafeArea()
            HomeView()
        }
        .preferredColorScheme(.dark)
    }
}
