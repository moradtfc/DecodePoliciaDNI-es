// UserDefaults+Onboarding.swift
// VerifyDNI
// Persistencia del estado de onboarding.

import Foundation

extension UserDefaults {
    static let onboardingCompletedKey = "verifydni.onboarding.completed"

    var hasCompletedOnboarding: Bool {
        // DEBUG: forzar onboarding siempre — cambiar a false cuando esté validado
        get { false }
        set { set(newValue, forKey: Self.onboardingCompletedKey) }
    }
}
