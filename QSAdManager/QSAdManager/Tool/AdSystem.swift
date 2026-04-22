//
//  AdSystem.swift
//  QSAdManager
//
//  Created by Codex on 2026/4/22.
//

import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
/// 负责隐私授权与广告 SDK 初始化的统一入口。
public enum AdSystem {
    /// 当前生效的广告配置。
    private static var configuration: AdConfiguration?
    /// 正在执行的准备任务，用于避免重复并发初始化。
    private static var prepareTask: Task<ConsentResult, Never>?
    /// 是否已经启动过 Mobile Ads SDK。
    private static var isMobileAdsStarted = false

    /// 写入广告系统的全局配置。
    public static func configure(_ configuration: AdConfiguration) {
        self.configuration = configuration
    }

    /// 当前保存的广告配置。
    public static var currentConfiguration: AdConfiguration? {
        configuration
    }

    @discardableResult
    /// 执行广告系统准备流程，包括隐私授权和 SDK 启动。
    public static func prepare(presentingFrom viewController: UIViewController) async -> ConsentResult {
        if let prepareTask {
            return await prepareTask.value
        }

        let task = Task { @MainActor in
            await performPrepare(presentingFrom: viewController)
        }

        prepareTask = task
        let result = await task.value
        prepareTask = nil
        return result
    }

    /// 串行执行具体的准备逻辑。
    private static func performPrepare(presentingFrom viewController: UIViewController) async -> ConsentResult {
        let configuration = configuration ?? AdConfiguration(
            interstitialAdUnitID: "",
            bannerAdUnitID: ""
        )

        var umpStatus: ConsentStatus?
        var didPresentConsentForm = false

        if configuration.isUMPEnabled {
            do {
                umpStatus = try await requestConsentInfoUpdate(using: configuration)
            } catch {
                AdLogger.debug("Failed to refresh consent info: \(error.localizedDescription)")
                umpStatus = ConsentInformation.shared.consentStatus
            }
        }

        let attStatus = await requestTrackingAuthorizationIfNeeded(using: configuration)

        if configuration.isUMPEnabled {
            didPresentConsentForm = await presentConsentFormIfNeeded(from: viewController)
            umpStatus = ConsentInformation.shared.consentStatus
        }

        startMobileAdsIfNeeded()

        return ConsentResult(
            umpStatus: umpStatus,
            attStatus: attStatus,
            didPresentConsentForm: didPresentConsentForm,
            canRequestAds: configuration.isUMPEnabled ? ConsentInformation.shared.canRequestAds : true
        )
    }

    /// 刷新 UMP 同意信息。
    private static func requestConsentInfoUpdate(using configuration: AdConfiguration) async throws -> ConsentStatus {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = configuration.isTaggedForUnderAgeOfConsent

#if DEBUG
        if let debugConfiguration = configuration.debugConfiguration {
            let debugSettings = DebugSettings()
            debugSettings.geography = debugConfiguration.geography
            debugSettings.testDeviceIdentifiers = debugConfiguration.testDeviceIdentifiers
            parameters.debugSettings = debugSettings
        }
#endif

        return try await withCheckedThrowingContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: ConsentInformation.shared.consentStatus)
            }
        }
    }

    /// 根据配置请求 ATT 授权。
    private static func requestTrackingAuthorizationIfNeeded(
        using configuration: AdConfiguration
    ) async -> ATTrackingManager.AuthorizationStatus? {
        guard configuration.isATTAuthorizationEnabled else {
            return nil
        }

        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await ATTrackingManager.requestTrackingAuthorization()
    }

    /// 在需要时加载并展示 UMP 同意表单。
    private static func presentConsentFormIfNeeded(from viewController: UIViewController) async -> Bool {
        guard ConsentInformation.shared.consentStatus == .required else {
            return false
        }

        do {
            let form = try await loadConsentForm()
            try await presentConsentForm(form, from: viewController)
            return true
        } catch {
            AdLogger.debug("Failed to present consent form: \(error.localizedDescription)")
            return false
        }
    }

    /// 异步加载一份同意表单。
    private static func loadConsentForm() async throws -> ConsentForm {
        try await withCheckedThrowingContinuation { continuation in
            ConsentForm.load { form, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let form else {
                    continuation.resume(throwing: AdSystemError.missingAdUnitID("Consent form"))
                    return
                }

                continuation.resume(returning: form)
            }
        }
    }

    /// 展示已经加载完成的同意表单。
    private static func presentConsentForm(
        _ form: ConsentForm,
        from viewController: UIViewController
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            form.present(from: viewController) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume()
            }
        }
    }

    /// 在首次准备完成后启动 Google Mobile Ads SDK。
    private static func startMobileAdsIfNeeded() {
        guard isMobileAdsStarted == false else {
            return
        }

        isMobileAdsStarted = true
        MobileAds.shared.start()
    }
}
