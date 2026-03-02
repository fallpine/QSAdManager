//
//  InterstitialAdTool.swift
//  QSAdManager
//
//  Created by ht on 2026/3/2.
//

import GoogleMobileAds

public class InterstitialAdTool: NSObject {
    /// 加载广告
    public func loadAd() async {
        do {
            interstitialAd = try await InterstitialAd.load(
                with: AdManager.interstitialAdId, request: Request()
            )
            interstitialAd?.fullScreenContentDelegate = self
        } catch {
            #if DEBUG
            print("Failed to load interstitial ad with error: \(error.localizedDescription)")
            #endif
        }
    }

    /// 展示广告
    public func showAd(from vc: UIViewController, onClose: @escaping (() -> Void)) {
        self.onClose = onClose
        // 广告已准备好
        if let ad = interstitialAd {
            ad.present(from: vc)
        } else {
            onClose()
        }
    }
    
    // MARK: - Property
    private var showCount = 0
    // 广告对象
    private var interstitialAd: InterstitialAd?
    private var onClose: (() -> Void)?
    
    // MARK: - 单例
    private static var _shareInstance: InterstitialAdTool?
    static public var shared: InterstitialAdTool {
        guard let instance = _shareInstance else {
            _shareInstance = InterstitialAdTool()
            return _shareInstance!
        }
        
        return instance
    }
}

extension InterstitialAdTool: FullScreenContentDelegate {
    /// 广告即将显示
    public func adWillPresentFullScreenContent(_: any FullScreenPresentingAd) {
        showCount += 1
    }

    /// 广告消失
    public func adDidDismissFullScreenContent(_: any FullScreenPresentingAd) {
        interstitialAd = nil

        onClose?()
        if showCount >= (AdManager.interstitialAdCount ?? 0) {
            return
        }
        Task {
            await loadAd()
        }
    }
}
