# Podfile — VerifID
# Instalar con: pod install
# Abrir siempre VerifyDNI.xcworkspace (no el .xcodeproj)

platform :ios, '16.0'
warn_for_unused_master_specs_repo => false

use_frameworks!

target 'VerifyDNI' do
  pod 'GoogleMLKit/BarcodeScanning', '8.0.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
