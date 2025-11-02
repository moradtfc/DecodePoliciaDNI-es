//
//  SceneDelegate.swift
//  DecodePoliciaDNI
//
//  Created by Claude on 2/11/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else {
            print("❌ No se pudo obtener windowScene")
            return
        }

        print("🚀 SceneDelegate - willConnectTo")
        print("📱 WindowScene bounds: \(windowScene.coordinateSpace.bounds)")

        // Create window
        window = UIWindow(windowScene: windowScene)
        print("✅ Window creado")

        // Create main view controller
        let mainViewController = MainViewController()
        let navigationController = UINavigationController(rootViewController: mainViewController)
        print("✅ MainViewController y NavigationController creados")

        // Set root view controller
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        print("✅ Window visible")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}
