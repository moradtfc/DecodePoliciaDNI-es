# VerifyDNI — Datos para App Store Connect

> Rellena los campos marcados con `[ ... ]`. El resto está listo para copiar y pegar.

## Información de la app
| Campo | Valor |
|---|---|
| Nombre (máx. 30) | VerifyDNI |
| Subtítulo (máx. 30) | Verifica DNI por QR y NFC |
| Bundle ID | com.jesusmora.VerifyDNI |
| SKU | verifydni-ios-001 |
| Idioma principal | Español (España) |
| Categoría principal | Utilidades |
| Categoría secundaria | Negocios |
| Clasificación por edad | 4+ (sin contenido sensible) |
| Versión | 1.0 (build 1) |
| Precio | Gratis |
| Copyright | © 2026 Jesús Alberto Mora |
| URL de soporte | `[https://...]` (obligatoria) |
| URL de política de privacidad | `[https://...]` (obligatoria — ver `PRIVACY_POLICY_ES.md`) |
| URL de marketing | opcional |

## Palabras clave (máx. 100 caracteres)
`DNI,NFC,QR,MiDNI,verificar,identidad,MRZ,documento,edad,mayor de edad,comprobar`

## Texto promocional (máx. 170)
Comprueba en segundos si un DNI es auténtico: escanea el QR de MiDNI o lee el chip NFC del DNI físico. Sin registros, sin cuentas.

## Descripción
VerifyDNI es una herramienta para comprobar la autenticidad de un documento de identidad español de forma rápida y privada.

• DNI digital (MiDNI): escanea el código QR y la app verifica la firma digital ECDSA del documento frente al certificado público oficial, comprobando además que el QR no ha caducado.
• DNI físico, TIE y pasaporte: apunta la cámara a la zona MRZ y acerca el documento al iPhone para leer el chip NFC.
• Resultado claro: datos del titular, foto, fecha de caducidad e indicador de mayoría de edad.
• Privacidad: la lectura y la verificación se realizan en tu dispositivo. VerifyDNI no crea cuentas, no guarda los datos del documento y no los envía a ningún servidor.
• Tutorial integrado que te guía paso a paso.

Requisitos: iPhone 7 o posterior con NFC para la lectura del chip. La lectura de QR funciona en cualquier iPhone compatible.

Aviso: VerifyDNI es una aplicación independiente y no está afiliada ni respaldada por la Policía Nacional ni por el Ministerio del Interior.

## Novedades de la versión 1.0
Primera versión de VerifyDNI.

## Etiquetas de privacidad (App Privacy)
- **¿Recopilas datos?** → **No se recopilan datos** (los datos del documento se procesan solo en el dispositivo y no salen de él; no hay analítica propia ni publicidad ni tracking).
- El SDK Google ML Kit (escaneo de códigos) se ejecuta en el dispositivo; incluye sus propios manifiestos de privacidad.
- Tracking (ATT): **No**. No hace falta `NSUserTrackingUsageDescription`.
- Cifrado: `ITSAppUsesNonExemptEncryption = NO` (ya incluido en Info.plist; solo cifrado estándar del sistema).

> ⚠️ Si activas el envío de verificaciones a Supabase (hoy el código existe en `WebSocketManager` pero ninguna pantalla lo invoca), tendrás que declarar "Datos de contacto / Contenido del usuario / Identificadores sensibles" en App Privacy y actualizar la política.

## Notas para el revisor de App Review
VerifyDNI verifies Spanish identity documents. No login or demo account is required.

- QR mode: point the camera at a Spanish "MiDNI" QR code. The signature is verified offline against the public APPDNIMOVIL certificate bundled in the app (it can also be refreshed from the public PKI server pki.policia.es over HTTPS).
- NFC mode: the app first scans the MRZ with the camera and then reads the chip of the physical ID (NFC Tag Reading, ISO 7816, eMRTD application A0000002471001). This requires a physical Spanish ID card (DNI/TIE) or an ICAO passport. If you do not have one, the NFC screen can be reviewed up to the MRZ-scanning step.
- All data is processed on-device; nothing is uploaded or stored. The app is not affiliated with any government body and says so on the Profile screen.
- Camera is used for QR/MRZ scanning; NFC is used to read the document chip.

Contacto de revisión: `[nombre, teléfono, email]`

## Capturas de pantalla (obligatorias)
- iPhone 6,9" (1320×2868) — mínimo 3 capturas: Inicio, Escaneo QR/MRZ, Resultado.
- iPad 13" solo si mantienes iPad como dispositivo soportado (ver abajo).

## Decisiones pendientes
1. **iPad**: la app declara iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`), pero los iPad no tienen NFC. Si solo quieres iPhone, cambia ese valor a `1` y te ahorras las capturas de iPad.
2. **Compartir resultado** (WhatsApp/X/Telegram/Mail): envía datos personales del titular a apps externas por iniciativa del usuario. Es válido, pero explícalo en la política de privacidad.
