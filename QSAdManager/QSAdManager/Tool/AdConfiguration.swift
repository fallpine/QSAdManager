//
//  AdConfiguration.swift
//  QSAdManager
//
//  Created by Codex on 2026/4/22.
//

import Foundation
import AppTrackingTransparency
import UserMessagingPlatform

/// 广告系统的全局配置。
public struct AdConfiguration {
    /// UMP 调试配置。
    public struct DebugConfiguration {
        /// 指定调试时使用的地理区域。
        public let geography: DebugGeography
        /// 标记为测试设备的设备标识列表。
        public let testDeviceIdentifiers: [String]

        /// 创建一份 UMP 调试配置。
        public init(geography: DebugGeography, testDeviceIdentifiers: [String] = []) {
            self.geography = geography
            self.testDeviceIdentifiers = testDeviceIdentifiers
        }
    }

    /// 插屏广告位 ID。
    public let interstitialAdUnitID: String
    /// Banner 广告位 ID。
    public let bannerAdUnitID: String
    /// 插屏广告最多允许展示的次数，`nil` 表示不限制。
    public let maxInterstitialDisplays: Int?
    /// 是否启用 UMP 隐私同意流程。
    public let isUMPEnabled: Bool
    /// 是否启用 ATT 授权请求。
    public let isATTAuthorizationEnabled: Bool
    /// 是否按未成年人同意场景标记请求。
    public let isTaggedForUnderAgeOfConsent: Bool
    /// 调试环境下使用的 UMP 调试配置。
    public let debugConfiguration: DebugConfiguration?

    /// 创建广告系统配置。
    public init(
        interstitialAdUnitID: String,
        bannerAdUnitID: String,
        maxInterstitialDisplays: Int? = nil,
        isUMPEnabled: Bool = true,
        isATTAuthorizationEnabled: Bool = true,
        isTaggedForUnderAgeOfConsent: Bool = false,
        debugConfiguration: DebugConfiguration? = nil
    ) {
        self.interstitialAdUnitID = interstitialAdUnitID
        self.bannerAdUnitID = bannerAdUnitID
        self.maxInterstitialDisplays = maxInterstitialDisplays
        self.isUMPEnabled = isUMPEnabled
        self.isATTAuthorizationEnabled = isATTAuthorizationEnabled
        self.isTaggedForUnderAgeOfConsent = isTaggedForUnderAgeOfConsent
        self.debugConfiguration = debugConfiguration
    }
}

/// Banner 广告的展示选项。
public struct BannerAdOptions {
    /// 可折叠 Banner 的展示位置。
    public enum CollapsiblePlacement: String {
        case top
        case bottom
    }

    /// 可折叠 Banner 的位置，`nil` 表示关闭该特性。
    public let collapsiblePlacement: CollapsiblePlacement?
    /// 是否在加载期间显示骨架屏占位。
    public let showsLoadingSkeleton: Bool

    /// 创建 Banner 广告展示选项。
    public init(
        collapsiblePlacement: CollapsiblePlacement? = nil,
        showsLoadingSkeleton: Bool = true
    ) {
        self.collapsiblePlacement = collapsiblePlacement
        self.showsLoadingSkeleton = showsLoadingSkeleton
    }
}

/// 隐私授权与广告请求准备阶段的结果。
public struct ConsentResult {
    /// UMP 当前的同意状态。
    public let umpStatus: ConsentStatus?
    /// ATT 当前的授权状态。
    public let attStatus: ATTrackingManager.AuthorizationStatus?
    /// 本次流程是否实际弹出了同意表单。
    public let didPresentConsentForm: Bool
    /// 当前是否已经允许请求广告。
    public let canRequestAds: Bool

    /// 创建一份隐私授权流程结果。
    public init(
        umpStatus: ConsentStatus?,
        attStatus: ATTrackingManager.AuthorizationStatus?,
        didPresentConsentForm: Bool,
        canRequestAds: Bool
    ) {
        self.umpStatus = umpStatus
        self.attStatus = attStatus
        self.didPresentConsentForm = didPresentConsentForm
        self.canRequestAds = canRequestAds
    }
}

/// 插屏广告展示结果。
public enum InterstitialPresentationResult {
    case displayed
    case dismissed
    case notReady
    case exhausted
    case failed(Error)
}

/// Banner 广告的关键事件。
public enum BannerAdEvent {
    case loaded
    case failed(Error)
    case impressionRecorded
    case clicked
}

/// 广告系统内部错误定义。
enum AdSystemError: LocalizedError {
    case missingAdUnitID(String)

    /// 错误的人类可读描述。
    var errorDescription: String? {
        switch self {
        case let .missingAdUnitID(placement):
            return "\(placement) ad unit ID is empty."
        }
    }
}

/// 广告系统的调试日志工具。
enum AdLogger {
    /// 在 Debug 环境输出日志。
    static func debug(_ message: @autoclosure () -> String) {
#if DEBUG
        print("[AdSystem] \(message())")
#endif
    }
}
