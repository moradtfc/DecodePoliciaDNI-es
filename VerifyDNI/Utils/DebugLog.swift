// DebugLog.swift
// VerifyDNI
//
// Logging solo para builds de desarrollo. En Release no emite nada, de forma que
// datos personales del documento (nº de DNI, fechas, MRZ, nombres…) nunca
// terminan en el registro del sistema del dispositivo.

import Foundation

@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
