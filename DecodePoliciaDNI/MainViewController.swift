//
//  MainViewController.swift
//  DecodePoliciaDNI
//
//  Created by Claude on 2/11/25.
//

import UIKit

class MainViewController: UIViewController {

    // MARK: - UI Components

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "qrcode.viewfinder")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Escáner miDNI"
        label.font = UIFont.boldSystemFont(ofSize: 34)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Escanea el código QR de tu DNI digital español para verificar la información"
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Escanear código QR", for: .normal)
        button.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        button.tintColor = .white
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 15
        button.translatesAutoresizingMaskIntoConstraints = false

        // Configurar el espaciado entre icono y texto
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)

        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🎬 MainViewController - viewDidLoad()")
        setupUI()
        setupNavigationBar()
        print("✅ MainViewController - UI configurada")
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Add subviews
        view.addSubview(iconImageView)
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(scanButton)

        // Setup constraints
        NSLayoutConstraint.activate([
            // Icon
            iconImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 150),
            iconImageView.heightAnchor.constraint(equalToConstant: 150),

            // Title
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            // Description
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            // Scan Button
            scanButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 30),
            scanButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            scanButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            scanButton.heightAnchor.constraint(equalToConstant: 56)
        ])

        // Add button action
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
    }

    private func setupNavigationBar() {
        title = "miDNI Scanner"
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    // MARK: - Actions

    @objc private func scanButtonTapped() {
        print("🚀 Abriendo escáner de QR...")
        let scannerVC = QRScannerViewController()
        print("✅ QRScannerViewController creado")
        let navController = UINavigationController(rootViewController: scannerVC)
        navController.modalPresentationStyle = .fullScreen
        print("✅ NavigationController configurado, presentando...")
        present(navController, animated: true) {
            print("✅ QRScannerViewController presentado")
        }
    }
}
