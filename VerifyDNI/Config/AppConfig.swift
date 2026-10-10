// AppConfig.swift
// VerifyDNI
//
// Constantes globales de configuración.

import Foundation

enum AppConfig {

    // MARK: - Supabase (Realtime y almacenamiento)

    /// URL del proyecto Supabase.
    static let supabaseURL = "https://lmfpxokhgcjoqoqedixe.supabase.co"

    /// Clave pública anon de Supabase.
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxtZnB4b2toZ2Nqb3FvcWVkaXhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUyMTkxNzcsImV4cCI6MjA5MDc5NTE3N30.f_G3GjegqYM9cBW8dihr02IjQP-j9RIwe6OO8NHrdy4"

    // MARK: - Certificado MiDNI

    /// URL del certificado X.509 de la Policía Nacional (formato DER).
    static let certURL = "https://lmfpxokhgcjoqoqedixe.supabase.co/storage/v1/object/public/certificates/midni_cert.der"

    // MARK: - Keychain

    /// Servicio Keychain para el certificado en caché.
    static let keychainService = "com.verifydni.midni"

    /// Cuenta Keychain para el certificado.
    static let keychainCertAccount = "midni_certificate"

    // MARK: - Realtime

    /// Prefijo de canal Realtime para verificaciones.
    /// Canal completo: "verification:<accountId>"
    static let realtimeChannelPrefix = "verification"

    // MARK: - Tabla Supabase

    static let verificationsTable = "verifications"
}
