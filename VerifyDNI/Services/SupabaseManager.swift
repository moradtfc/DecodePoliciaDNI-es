// SupabaseManager.swift
// VerifyDNI
//
// Singleton que expone el cliente Supabase compartido.
// Usado por WebSocketManager para conexiones Realtime.

import Foundation
import Supabase

final class SupabaseManager {

    static let shared = SupabaseManager()
    private init() {}

    /// Cliente Supabase configurado con la URL y clave de AppConfig.
    lazy var client: SupabaseClient = {
        guard let url = URL(string: AppConfig.supabaseURL) else {
            fatalError("AppConfig.supabaseURL no es una URL válida")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: AppConfig.supabaseAnonKey
        )
    }()
}
