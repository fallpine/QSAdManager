//
//  ViewController.swift
//  QSAdManager
//
//  Created by ht on 2026/3/2.
//

import UIKit

final class ViewController: UIViewController {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "QSAdManager Demo"
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "点击下方按钮进入广告展示页面。"
        return label
    }()

    private let openDemoButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = .filled()
        button.configuration?.title = "进入广告 Demo"
        button.configuration?.cornerStyle = .large
        button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "首页"
        view.backgroundColor = .systemBackground
        setupViews()
    }

    private func setupViews() {
        openDemoButton.addTarget(self, action: #selector(openDemoButtonTapped), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, openDemoButton])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 16

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            openDemoButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
    }

    @objc
    private func openDemoButtonTapped() {
        let demoViewController = AdDemoViewController()

        if let navigationController {
            navigationController.pushViewController(demoViewController, animated: true)
            return
        }

        let wrappedNavigationController = UINavigationController(rootViewController: demoViewController)
        wrappedNavigationController.modalPresentationStyle = .fullScreen
        present(wrappedNavigationController, animated: true)
    }
}
