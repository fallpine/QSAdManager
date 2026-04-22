//
//  AdDemoViewController.swift
//  QSAdManager
//
//  Created by Codex on 2026/4/22.
//

import UIKit

@MainActor
final class AdDemoViewController: UIViewController {
    private enum DemoAdUnitID {
        static let banner = "ca-app-pub-3940256099942544/2435281174"    // 测试id
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"        // 测试id
    }

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "底部会自动加载 Banner 广告，点击按钮尝试展示插屏广告。"
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "广告初始化中..."
        return label
    }()

    private let showInterstitialButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = .filled()
        button.configuration?.title = "显示插屏广告"
        button.configuration?.cornerStyle = .large
        button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        return button
    }()

    private lazy var bannerContainer: BannerAdContainerView = {
        let view = BannerAdContainerView(
            adUnitID: DemoAdUnitID.banner,
            rootViewController: self
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var interstitialController = InterstitialAdController(
        adUnitID: DemoAdUnitID.interstitial
    )

    private var hasStartedPrepareFlow = false
    private var hasStartedBannerLoad = false
    private var hasStartedInterstitialPreload = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "广告 Demo"
        view.backgroundColor = .systemBackground

        configureAdSystem()
        setupViews()
        bindBannerEvents()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAdFlowIfNeeded()
    }

    private func configureAdSystem() {
        AdSystem.configure(
            AdConfiguration(
                interstitialAdUnitID: DemoAdUnitID.interstitial,
                bannerAdUnitID: DemoAdUnitID.banner
            )
        )
    }

    private func setupViews() {
        showInterstitialButton.addTarget(self, action: #selector(showInterstitialButtonTapped), for: .touchUpInside)

        let contentStackView = UIStackView(arrangedSubviews: [descriptionLabel, statusLabel, showInterstitialButton])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = 20

        view.addSubview(contentStackView)
        view.addSubview(bannerContainer)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            contentStackView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            contentStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentStackView.bottomAnchor.constraint(lessThanOrEqualTo: bannerContainer.topAnchor, constant: -24),

            bannerContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            bannerContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            bannerContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            bannerContainer.topAnchor.constraint(greaterThanOrEqualTo: contentStackView.bottomAnchor, constant: 24),

            showInterstitialButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
    }

    private func bindBannerEvents() {
        bannerContainer.onEvent = { [weak self] event in
            guard let self else {
                return
            }

            switch event {
            case .loaded:
                self.updateStatus("Banner 广告已加载。")
            case let .failed(error):
                self.updateStatus("Banner 加载失败: \(error.localizedDescription)")
            case .impressionRecorded:
                self.updateStatus("Banner 已记录曝光。")
            case .clicked:
                self.updateStatus("Banner 已点击。")
            }
        }
    }

    private func startAdFlowIfNeeded() {
        guard hasStartedPrepareFlow == false else {
            return
        }

        hasStartedPrepareFlow = true
        updateStatus("正在执行广告系统准备流程...")

        Task { [weak self] in
            guard let self else {
                return
            }

            let result = await AdSystem.prepare(presentingFrom: self)
            await self.handlePrepareResult(result)
        }
    }

    private func handlePrepareResult(_ result: ConsentResult) async {
        guard result.canRequestAds else {
            updateStatus("广告系统准备完成，但当前不可请求广告。")
            return
        }

        updateStatus("广告系统准备完成，开始加载 Banner 和插屏广告...")

        if hasStartedBannerLoad == false {
            hasStartedBannerLoad = true
            bannerContainer.loadAd()
        }

        preloadInterstitialIfNeeded()
    }

    private func preloadInterstitialIfNeeded() {
        guard hasStartedInterstitialPreload == false else {
            return
        }

        hasStartedInterstitialPreload = true
        updateStatus("正在预加载插屏广告...")

        Task { [weak self] in
            guard let self else {
                return
            }

            await self.interstitialController.preload()
            self.updateStatus("插屏广告预加载完成，可点击按钮尝试展示。")
        }
    }

    @objc
    private func showInterstitialButtonTapped() {
        updateStatus("正在尝试展示插屏广告...")

        Task { [weak self] in
            guard let self else {
                return
            }

            let result = await self.interstitialController.present(from: self)
            await self.handleInterstitialResult(result)
        }
    }

    private func handleInterstitialResult(_ result: InterstitialPresentationResult) async {
        switch result {
        case .displayed:
            updateStatus("插屏广告开始展示。")
        case .dismissed:
            updateStatus("插屏广告已关闭。")
        case .notReady:
            updateStatus("插屏广告尚未准备好，正在重新预加载...")
            hasStartedInterstitialPreload = false
            preloadInterstitialIfNeeded()
        case .exhausted:
            updateStatus("插屏广告展示次数已达上限。")
        case let .failed(error):
            updateStatus("插屏广告展示失败: \(error.localizedDescription)")
            hasStartedInterstitialPreload = false
            preloadInterstitialIfNeeded()
        }
    }

    private func updateStatus(_ message: String) {
        statusLabel.text = message
        AdLogger.debug(message)
    }
}
