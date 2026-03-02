//
//  AdManager.swift
//  QSAdManager
//
//  Created by ht on 2026/3/2.
//

import AppTrackingTransparency
import UserMessagingPlatform
import GoogleMobileAds

public class AdManager {
    // MARK: - Func
    /// 获取权限
    static public func requestAuthorization(currentVc: UIViewController) {
        if ATTrackingManager.trackingAuthorizationStatus == .authorized {
            return
        }
        
        Task {
            /// 隐私跟踪授权
            let status = await ATTrackingManager.requestTrackingAuthorization()
            if status == .authorized {
                _requestUMPAuthorization(currentVc: currentVc)
            }
        }
    }
    
    /// UMP授权
    static private func _requestUMPAuthorization(currentVc: UIViewController) {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false // 根据需要设置
        
        let debugSettings = DebugSettings.init()
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
            if let error = error {
#if DEBUG
                print("Error requesting consent info update: \(error.localizedDescription)")
#endif
                return
            }
            
            // Step 2: Check consent status
            let consentStatus = ConsentInformation.shared.consentStatus
            if consentStatus == .obtained {
            } else if consentStatus == .required {
                // Step 3: Load and present consent form
                ConsentForm.load { form, loadError in
                    if let loadError = loadError {
#if DEBUG
                print("Error loading consent form: \(loadError.localizedDescription)")
#endif
                        return
                    }
                    form?.present(from: currentVc) { dismissError in
#if DEBUG
                        print("Error loading consent form: \(dismissError?.localizedDescription ?? "")")
#endif
                    }
                }
            }
        }
    }
    
    /// 开启AdMob
    static public func startAdMob(with interstitialAdId: String, interstitialAdCount: Int?) {
#if DEBUG
        self.interstitialAdId = "ca-app-pub-3940256099942544/4411468910"
#else
        self.interstitialAdId = interstitialAdId
#endif
        self.interstitialAdCount = interstitialAdCount
        
        MobileAds.shared.start()
    }
    
    // MARK: - Property
    static var interstitialAdId = ""
    static var interstitialAdCount: Int?
}
