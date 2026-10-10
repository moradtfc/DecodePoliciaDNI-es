// MainTabView.swift
// VerifyDNI
// Vista raíz: gestiona el tab bar flotante Liquid Glass
// y el ciclo de vida del WebSocket.

import SwiftUI

struct MainTabView: View {

    @EnvironmentObject private var wsManager: WebSocketManager
    @State private var selectedTab: Tab = .home

    enum Tab { case home, profile }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Fondo base global
            Color(hex: "#040D1A").ignoresSafeArea()

            // Contenido de la tab seleccionada
            tabContent
                .animation(.easeInOut(duration: 0.2), value: selectedTab)

            // Tab bar flotante
            floatingTabBar
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            HomeView()
                .transition(.opacity)
        case .profile:
            ProfileView()
                .transition(.opacity)
        }
    }

    // MARK: - Floating Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabBarButton(tab: .home,    icon: "house.fill",   label: "Inicio")
            tabBarButton(tab: .profile, icon: "person.fill",  label: "Perfil")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(liquidGlassBackground)
        .shadow(color: Color(hex: "#1877FF").opacity(0.12), radius: 20, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.30),           radius: 10, x: 0, y: 4)
        // 24 pt por encima del safe area inferior
        .padding(.bottom, 24 + (UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?
            .safeAreaInsets.bottom ?? 0))
    }

    private var liquidGlassBackground: some View {
        ZStack {
            // Capa 1 – blur
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
            // Capa 2 – tinte azul sutil
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#1877FF").opacity(0.08),
                            Color(hex: "#040D1A").opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            // Capa 3 – borde luminoso
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Tab Bar Button

    private func tabBarButton(tab: Tab, icon: String, label: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color(hex: "#1877FF").opacity(0.18))
                            .frame(width: 42, height: 28)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Image(systemName: icon)
                        .font(.system(
                            size:   isSelected ? 18 : 17,
                            weight: isSelected ? .semibold : .regular
                        ))
                        .foregroundColor(
                            isSelected ? Color(hex: "#60A5FA") : Color(white: 0.45)
                        )
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.7),
                            value: isSelected
                        )
                }
                .frame(width: 42, height: 28)

                Text(label)
                    .font(.system(
                        size:   10,
                        weight: isSelected ? .semibold : .regular
                    ))
                    .foregroundColor(
                        isSelected ? Color(hex: "#60A5FA") : Color(white: 0.35)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
    }
}
