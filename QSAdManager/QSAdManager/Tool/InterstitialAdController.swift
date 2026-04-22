//
//  InterstitialAdController.swift
//  QSAdManager
//
//  Created by Codex on 2026/4/22.
//

import UIKit
import GoogleMobileAds

@MainActor
/// 管理插屏广告的预加载、展示和次数限制。
public final class InterstitialAdController: NSObject {
    /// 插屏广告内部状态机。
    private enum State {
        case idle
        case loading
        case ready(InterstitialAd)
        case presenting
        case exhausted
        case failed(Error)
    }

    /// 插屏广告位 ID。
    public let adUnitID: String
    /// 插屏广告最大展示次数，`nil` 表示不限制。
    public let maxDisplayCount: Int?
    /// 当前已经成功展示过的次数。
    public private(set) var displayCount = 0
    /// 最近一次展示尝试的结果。
    public private(set) var lastPresentationResult: InterstitialPresentationResult?

    /// 当前插屏广告控制器状态。
    private var state: State
    /// 当前已加载成功并可展示的广告对象。
    private var activeAd: InterstitialAd?
    /// 等待展示结果返回的异步 continuation。
    private var presentationContinuation: CheckedContinuation<InterstitialPresentationResult, Never>?

    /// 创建一个插屏广告控制器。
    public init(adUnitID: String, maxDisplayCount: Int? = nil) {
        self.adUnitID = adUnitID
        self.maxDisplayCount = maxDisplayCount
        self.state = maxDisplayCount == 0 ? .exhausted : .idle
        super.init()
    }

    /// 预加载一条插屏广告。
    public func preload() async {
        guard adUnitID.isEmpty == false else {
            state = .failed(AdSystemError.missingAdUnitID("Interstitial"))
            return
        }

        guard maxDisplayCount != 0 else {
            state = .exhausted
            return
        }

        switch state {
        case .loading, .presenting, .ready, .exhausted:
            return
        case .idle, .failed:
            break
        }

        state = .loading

        do {
            let ad = try await InterstitialAd.load(with: adUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            activeAd = ad
            state = .ready(ad)
        } catch {
            activeAd = nil
            state = .failed(error)
            AdLogger.debug("Failed to preload interstitial ad: \(error.localizedDescription)")
        }
    }

    /// 在指定控制器上展示已经准备好的插屏广告。
    public func present(from viewController: UIViewController) async -> InterstitialPresentationResult {
        if maxDisplayCount == 0 {
            state = .exhausted
            lastPresentationResult = .exhausted
            return .exhausted
        }

        if hasReachedDisplayLimit {
            state = .exhausted
            lastPresentationResult = .exhausted
            return .exhausted
        }

        guard case let .ready(ad) = state else {
            lastPresentationResult = .notReady
            return .notReady
        }

        state = .presenting
        activeAd = ad

        return await withCheckedContinuation { continuation in
            presentationContinuation = continuation
            ad.present(from: viewController)
        }
    }

    /// 当前是否已经达到展示上限。
    private var hasReachedDisplayLimit: Bool {
        guard let maxDisplayCount else {
            return false
        }

        return displayCount >= maxDisplayCount
    }

    /// 结束展示流程并恢复等待中的异步调用。
    private func finishPresentation(after result: InterstitialPresentationResult) {
        lastPresentationResult = result

        if let continuation = presentationContinuation {
            presentationContinuation = nil
            continuation.resume(returning: result)
        }
    }

    /// 在广告展示完成后重置状态，并尝试补充下一条广告。
    private func resetAfterPresentationShouldReload() {
        activeAd = nil

        if hasReachedDisplayLimit {
            state = .exhausted
            return
        }

        state = .idle
        Task { @MainActor [weak self] in
            await self?.preload()
        }
    }

    /// 在广告展示失败后重置状态，并尝试重新预加载。
    private func resetAfterFailedPresentation(_ error: Error) {
        activeAd = nil
        state = .failed(error)

        Task { @MainActor [weak self] in
            await self?.preload()
        }
    }
}

extension InterstitialAdController: FullScreenContentDelegate {
    /// 插屏即将展示时记录展示次数。
    public func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        displayCount += 1
        lastPresentationResult = .displayed
    }

    /// 插屏关闭后完成本次展示流程。
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation(after: .dismissed)
        resetAfterPresentationShouldReload()
    }

    /// 插屏展示失败时完成本次展示流程并重新进入预加载。
    public func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        AdLogger.debug("Failed to present interstitial ad: \(error.localizedDescription)")
        finishPresentation(after: .failed(error))
        resetAfterFailedPresentation(error)
    }
}
