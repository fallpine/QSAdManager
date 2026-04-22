# QSAdManager

`QSAdManager` 是一个基于 `Google-Mobile-Ads-SDK` 的 iOS 广告管理插件，封装了以下能力：

- 广告系统统一配置
- UMP 隐私授权准备
- ATT 授权请求
- Banner 广告容器视图
- 插屏广告预加载与展示

目前插件源码位于 `QSAdManager/QSAdManager/Tool`，适合直接通过 CocoaPods 集成到 iOS 项目中。

## 环境要求

- iOS 15.0+
- Swift 5
- CocoaPods

## 安装

在你的 `Podfile` 中添加：

```ruby
pod 'QSAdManager', :git => 'https://github.com/fallpine/QSAdManager.git', :tag => '1.0.1'
```

然后执行：

```bash
pod install
```

## Google AdMob 官方文档

接入本插件前，建议先完成 Google AdMob 的基础配置，包括应用注册、广告位创建以及 AdMob SDK 基本初始化信息配置。

- AdMob iOS 快速开始文档：[https://developers.google.com/admob/ios/quick-start?hl=zh-cn](https://developers.google.com/admob/ios/quick-start?hl=zh-cn)

## 快速开始

### 1. 配置广告系统

在应用启动后，先设置广告配置：

```swift
import UIKit
import UserMessagingPlatform

let adConfiguration = AdConfiguration(
    interstitialAdUnitID: "your_interstitial_ad_unit_id",
    bannerAdUnitID: "your_banner_ad_unit_id",
    maxInterstitialDisplays: 3,
    isUMPEnabled: true,
    isATTAuthorizationEnabled: true,
    isTaggedForUnderAgeOfConsent: false,
    debugConfiguration: AdConfiguration.DebugConfiguration(
        geography: .disabled,
        testDeviceIdentifiers: []
    )
)

AdSystem.configure(adConfiguration)
```

### 2. 在可展示页面执行准备流程

在需要开始请求广告的页面中调用：

```swift
import UIKit

@MainActor
func prepareAds(from viewController: UIViewController) async {
    let result = await AdSystem.prepare(presentingFrom: viewController)
    print("UMP 状态: \(String(describing: result.umpStatus))")
    print("ATT 状态: \(String(describing: result.attStatus))")
    print("是否可请求广告: \(result.canRequestAds)")
}
```

这个步骤会按当前配置处理：

- UMP 同意信息刷新
- ATT 授权请求
- 必要时展示同意弹窗
- 启动 `Google Mobile Ads` SDK

## Banner 广告使用方法

`BannerAdContainerView` 是一个可直接加入页面的 Banner 容器视图，内置加载占位态与事件回调。

```swift
import UIKit

final class BannerExampleViewController: UIViewController {
    private lazy var bannerView = BannerAdContainerView(
        adUnitID: "your_banner_ad_unit_id",
        rootViewController: self,
        options: BannerAdOptions(
            collapsiblePlacement: nil,
            showsLoadingSkeleton: true
        )
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            bannerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            bannerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            bannerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])

        bannerView.onEvent = { event in
            switch event {
            case .loaded:
                print("Banner 加载成功")
            case .failed(let error):
                print("Banner 加载失败: \(error.localizedDescription)")
            case .impressionRecorded:
                print("Banner 曝光")
            case .clicked:
                print("Banner 点击")
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bannerView.loadAd()
    }
}
```

### Banner 配置项

- `collapsiblePlacement`
  可选值为 `.top` 或 `.bottom`，用于折叠 Banner 场景。
- `showsLoadingSkeleton`
  控制加载阶段是否显示骨架屏占位。

## 插屏广告使用方法

`InterstitialAdController` 负责插屏广告的预加载、展示和次数控制。

```swift
import UIKit

@MainActor
final class InterstitialExampleViewController: UIViewController {
    private let interstitialController = InterstitialAdController(
        adUnitID: "your_interstitial_ad_unit_id",
        maxDisplayCount: 3
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            await interstitialController.preload()
        }
    }

    @IBAction func showInterstitialAd() {
        Task {
            let result = await interstitialController.present(from: self)

            switch result {
            case .displayed:
                print("插屏开始展示")
            case .dismissed:
                print("插屏已关闭")
            case .notReady:
                print("插屏尚未准备好，重新预加载")
                await interstitialController.preload()
            case .exhausted:
                print("插屏展示次数已用完")
            case .failed(let error):
                print("插屏展示失败: \(error.localizedDescription)")
                await interstitialController.preload()
            }
        }
    }
}
```

## 公开类型说明

### `AdConfiguration`

用于统一配置广告系统：

- `interstitialAdUnitID`
  插屏广告位 ID
- `bannerAdUnitID`
  Banner 广告位 ID
- `maxInterstitialDisplays`
  插屏广告展示上限，`nil` 表示不限制
- `isUMPEnabled`
  是否启用 UMP
- `isATTAuthorizationEnabled`
  是否请求 ATT 授权
- `isTaggedForUnderAgeOfConsent`
  是否按未成年人同意场景处理
- `debugConfiguration`
  UMP 调试配置

### `ConsentResult`

`AdSystem.prepare(...)` 的返回结果，包含：

- `umpStatus`
- `attStatus`
- `didPresentConsentForm`
- `canRequestAds`

### `BannerAdEvent`

Banner 事件包括：

- `.loaded`
- `.failed(Error)`
- `.impressionRecorded`
- `.clicked`

### `InterstitialPresentationResult`

插屏展示结果包括：

- `.displayed`
- `.dismissed`
- `.notReady`
- `.exhausted`
- `.failed(Error)`

## 推荐接入顺序

1. 按照 Google AdMob 官方文档完成应用和广告位配置。
2. 通过 CocoaPods 集成 `QSAdManager`。
3. 启动后调用 `AdSystem.configure(...)`。
4. 在可展示页面调用 `await AdSystem.prepare(presentingFrom:)`。
5. 页面中接入 `BannerAdContainerView` 或 `InterstitialAdController`。

## 示例说明

当前仓库中的示例 App 已包含一个广告 Demo 页面，用于演示：

- 底部 Banner 广告展示
- 点击按钮展示插屏广告

你也可以根据自己的业务页面直接复用 `Tool` 目录下的公开类型。

## License

MIT
