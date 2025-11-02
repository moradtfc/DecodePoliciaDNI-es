//
//  AppDelegate.swift
//  DecodePoliciaDNI
//
//  Created by Claude on 2/11/25.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        print("🚀 AppDelegate - didFinishLaunchingWithOptions")

        // Create window
        window = UIWindow(frame: UIScreen.main.bounds)
        print("✅ Window creado: \(UIScreen.main.bounds)")

        // Create main view controller
        let mainViewController = MainViewController()
        let navigationController = UINavigationController(rootViewController: mainViewController)
        print("✅ MainViewController y NavigationController creados")

        // Set root view controller
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        print("✅ Window visible")

        return true
    }
}
