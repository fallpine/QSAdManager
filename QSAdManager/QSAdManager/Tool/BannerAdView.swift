//
//  BannerAdView.swift
//  QSAdManager
//
//  Created by ht on 2026/3/2.
//

import UIKit
import SkeletonView
import GoogleMobileAds
import SnapKit

public class BannerAdView: UIView {
    // MARK: - System
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupSubViews()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience public init(rootViewController: UIViewController, bannerAdId: String) {
        self.init()
        
        bannerAdView.adUnitID = bannerAdId
        bannerAdView.rootViewController = rootViewController
    }
    
    // MARK: - Func
    private func setupSubViews() {
        isSkeletonable = true
        
        addSubview(bannerAdView)
        bannerAdView.snp.makeConstraints { make in
            make.height.equalTo(65.0)
            make.top.equalTo(3.0)
            make.bottom.equalTo(-3.0)
            make.leading.trailing.equalToSuperview()
        }
        
        addSubview(skeletonView1)
        skeletonView1.snp.makeConstraints { make in
            make.leading.equalTo(16.0)
            make.trailing.equalTo(-120.0)
            make.top.equalTo(10.0)
        }
        
        addSubview(skeletonView2)
        skeletonView2.snp.makeConstraints { make in
            make.left.equalTo(skeletonView1)
            make.right.equalTo(-50.0)
            make.top.equalTo(skeletonView1.snp.bottom).offset(10.0)
            make.height.equalTo(skeletonView1)
            make.bottom.equalTo(-10.0)
        }
    }
    
    /// 加载横幅广告
    public func loadAd() {
        if bannerAdView.superview == nil {
            return
        }

        showSkeletonAnimation()
        
        let size = largeAnchoredAdaptiveBanner(width: UIScreen.main.bounds.size.width - 5.0 * 2.0)
        bannerAdView.adSize = size
        bannerAdView.snp.updateConstraints { make in
            make.height.equalTo(size.size.height)
        }

        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["collapsible": "bottom"]
        request.register(extras)
        bannerAdView.load(request)
    }

    private func showSkeletonAnimation() {
        // 开始显示骨架动画
        showAnimatedGradientSkeleton()
    }

    private func hideSkeletonAnimation() {
        // 数据加载完成后隐藏骨架动画
        hideSkeleton()
    }
    
    // MARK: - Property
    public var onLoadFailure: (() -> Void)?
    
    // MARK: - Widget
    private lazy var bannerAdView: BannerView = {
        let view = BannerView()
        view.delegate = self
        return view
    }()

    private lazy var skeletonView1: UIView = {
        let view = UIView()
        view.isSkeletonable = true
        view.skeletonCornerRadius = 4.0
        return view
    }()

    private lazy var skeletonView2: UIView = {
        let view = UIView()
        view.isSkeletonable = true
        view.skeletonCornerRadius = 4.0
        return view
    }()
}

extension BannerAdView: BannerViewDelegate {
    public func bannerViewDidReceiveAd(_: BannerView) {
        hideSkeletonAnimation()
    }

    public func bannerView(_: BannerView, didFailToReceiveAdWithError _: any Error) {
        onLoadFailure?()
    }
}
