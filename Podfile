# Podfile — VerifID
# Instalar con: pod install
# Abrir siempre VerifyDNI.xcworkspace (no el .xcodeproj)

platform :ios, '17.0'
install! 'cocoapods', :warn_for_unused_master_specs_repo => false

project 'VerifyDNI.xcodeproj'
use_frameworks!

target 'VerifyDNI' do
  pod 'GoogleMLKit/BarcodeScanning', '8.0.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      # Evita el error de Xcode por pods con deployment target < 15.0
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end
