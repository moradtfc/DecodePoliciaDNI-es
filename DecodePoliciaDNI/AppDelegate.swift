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

        // Create window
        window = UIWindow(frame: UIScreen.main.bounds)

        // Create main view controller
        let mainViewController = MainViewController()
        let navigationController = UINavigationController(rootViewController: mainViewController)

        // Set root view controller
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
