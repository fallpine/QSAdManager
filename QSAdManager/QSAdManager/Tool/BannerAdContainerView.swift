//
//  BannerAdContainerView.swift
//  QSAdManager
//
//  Created by Codex on 2026/4/22.
//

import UIKit
import SkeletonView
import GoogleMobileAds
import SnapKit

@MainActor
/// 用于承载 Banner 广告并处理占位态的容器视图。
public final class BannerAdContainerView: UIView {
    /// 占位视图的显示状态。
    private enum PlaceholderState {
        case hidden
        case loading
        case empty
    }

    /// Banner 广告事件回调。
    public var onEvent: ((BannerAdEvent) -> Void)?

    /// 当前 Banner 使用的广告位 ID。
    private let adUnitID: String
    /// Banner 的额外展示选项。
    private let options: BannerAdOptions
    /// Banner 需要依附展示的控制器。
    private weak var rootViewController: UIViewController?

    /// 用于同步 Banner 高度的约束。
    private var heightConstraint: Constraint?
    /// 最近一次发起加载时使用的宽度。
    private var requestedWidth: CGFloat?
    /// 最近一次成功加载 Banner 的宽度。
    private var loadedWidth: CGFloat?
    /// 当前是否处于加载流程中。
    private var isLoading = false
    /// 当前是否存在待处理的加载请求。
    private var hasPendingLoadRequest = false
    /// 当前加载结束后是否需要立刻重新加载。
    private var shouldReloadAfterCurrentAttempt = false

    /// 创建一个 Banner 广告容器。
    public init(
        adUnitID: String,
        rootViewController: UIViewController,
        options: BannerAdOptions = .init()
    ) {
        self.adUnitID = adUnitID
        self.rootViewController = rootViewController
        self.options = options
        super.init(frame: .zero)
        setupViews()
    }

    /// Storyboard/XIB 初始化入口，当前不支持。
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 主动触发一次 Banner 加载。
    public func loadAd() {
        hasPendingLoadRequest = true
        setNeedsLayout()
        layoutIfNeeded()
        attemptLoadIfPossible(forceReload: true)
    }

    /// 在视图进入窗口后尝试处理挂起的加载请求。
    public override func didMoveToWindow() {
        super.didMoveToWindow()

        if window != nil {
            attemptLoadIfPossible(forceReload: false)
        }
    }

    /// 布局变更后检查是否需要按新宽度重新加载 Banner。
    public override func layoutSubviews() {
        super.layoutSubviews()
        scheduleReloadForWidthChangeIfNeeded()
        attemptLoadIfPossible(forceReload: false)
    }

    /// 初始化 Banner 视图和占位视图层级。
    private func setupViews() {
        clipsToBounds = true

        bannerAdView.adUnitID = adUnitID
        bannerAdView.rootViewController = rootViewController

        addSubview(bannerAdView)
        bannerAdView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            heightConstraint = make.height.equalTo(0).constraint
        }

        addSubview(placeholderContainerView)
        placeholderContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        placeholderContainerView.addSubview(placeholderLine1)
        placeholderLine1.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16.0)
            make.trailing.equalToSuperview().inset(120.0)
            make.top.equalToSuperview().offset(12.0)
            make.height.equalTo(10.0)
        }

        placeholderContainerView.addSubview(placeholderLine2)
        placeholderLine2.snp.makeConstraints { make in
            make.leading.equalTo(placeholderLine1)
            make.trailing.equalToSuperview().inset(50.0)
            make.top.equalTo(placeholderLine1.snp.bottom).offset(10.0)
            make.height.equalTo(placeholderLine1)
            make.bottom.lessThanOrEqualToSuperview().inset(12.0)
        }

        applyPlaceholderState(.hidden)
    }

    /// 当前可用于自适应 Banner 的有效宽度。
    private var usableWidth: CGFloat {
        let insetBounds = bounds.inset(by: safeAreaInsets)
        return floor(max(0, insetBounds.width))
    }

    /// 当容器宽度变化时标记一次重新加载。
    private func scheduleReloadForWidthChangeIfNeeded() {
        let width = usableWidth
        guard width > 0, let requestedWidth else {
            return
        }

        if abs(width - requestedWidth) > 0.5 {
            hasPendingLoadRequest = true
            shouldReloadAfterCurrentAttempt = isLoading
        }
    }

    /// 在条件满足时发起 Banner 加载。
    private func attemptLoadIfPossible(forceReload: Bool) {
        guard hasPendingLoadRequest else {
            return
        }

        guard window != nil else {
            return
        }

        guard let rootViewController else {
            return
        }

        guard adUnitID.isEmpty == false else {
            let error = AdSystemError.missingAdUnitID("Banner")
            hasPendingLoadRequest = false
            applyPlaceholderState(.empty)
            onEvent?(.failed(error))
            return
        }

        let width = usableWidth
        guard width > 0 else {
            return
        }

        if isLoading {
            shouldReloadAfterCurrentAttempt = true
            return
        }

        if forceReload == false, let loadedWidth, abs(loadedWidth - width) <= 0.5 {
            hasPendingLoadRequest = false
            return
        }

        hasPendingLoadRequest = false
        isLoading = true
        requestedWidth = width

        bannerAdView.rootViewController = rootViewController

        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        bannerAdView.adSize = adSize
        heightConstraint?.update(offset: adSize.size.height)

        applyPlaceholderState(.loading)

        let request = Request()
        if let collapsiblePlacement = options.collapsiblePlacement {
            let extras = Extras()
            extras.additionalParameters = ["collapsible": collapsiblePlacement.rawValue]
            request.register(extras)
        }

        bannerAdView.load(request)
    }

    /// 结束当前加载尝试，并在需要时重新发起请求。
    private func finishLoadAttempt() {
        isLoading = false

        let widthChangedDuringLoad = abs(usableWidth - (requestedWidth ?? 0)) > 0.5
        let shouldReload = shouldReloadAfterCurrentAttempt || widthChangedDuringLoad
        shouldReloadAfterCurrentAttempt = false

        if shouldReload {
            hasPendingLoadRequest = true
            attemptLoadIfPossible(forceReload: true)
        }
    }

    /// 根据状态切换占位视图表现。
    private func applyPlaceholderState(_ state: PlaceholderState) {
        switch state {
        case .hidden:
            placeholderContainerView.isHidden = true
            placeholderContainerView.hideSkeleton()
        case .loading:
            placeholderContainerView.isHidden = false
            placeholderLine1.backgroundColor = .clear
            placeholderLine2.backgroundColor = .clear
            if options.showsLoadingSkeleton {
                placeholderContainerView.showAnimatedGradientSkeleton()
            } else {
                placeholderContainerView.hideSkeleton()
            }
        case .empty:
            placeholderContainerView.isHidden = false
            placeholderContainerView.hideSkeleton()
            placeholderLine1.backgroundColor = .systemGray5
            placeholderLine2.backgroundColor = .systemGray5
        }
    }

    /// 实际承载 Google Banner 的视图。
    private lazy var bannerAdView: BannerView = {
        let view = BannerView()
        view.delegate = self
        return view
    }()

    /// Banner 加载期间显示的占位容器。
    private lazy var placeholderContainerView: UIView = {
        let view = UIView()
        view.isSkeletonable = true
        return view
    }()

    /// 占位骨架的第一条灰线。
    private lazy var placeholderLine1: UIView = {
        let view = UIView()
        view.isSkeletonable = true
        view.layer.cornerRadius = 4.0
        view.clipsToBounds = true
        return view
    }()

    /// 占位骨架的第二条灰线。
    private lazy var placeholderLine2: UIView = {
        let view = UIView()
        view.isSkeletonable = true
        view.layer.cornerRadius = 4.0
        view.clipsToBounds = true
        return view
    }()
}

extension BannerAdContainerView: BannerViewDelegate {
    /// Banner 成功加载后的回调。
    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        loadedWidth = requestedWidth
        applyPlaceholderState(.hidden)
        onEvent?(.loaded)
        finishLoadAttempt()
    }

    /// Banner 加载失败后的回调。
    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        loadedWidth = nil
        applyPlaceholderState(.empty)
        onEvent?(.failed(error))
        finishLoadAttempt()
    }

    /// Banner 记录曝光后的回调。
    public func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        onEvent?(.impressionRecorded)
    }

    /// Banner 被点击后的回调。
    public func bannerViewDidRecordClick(_ bannerView: BannerView) {
        onEvent?(.clicked)
    }
}
