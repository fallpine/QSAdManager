Pod::Spec.new do |spec|
  spec.name         = "QSAdManager"
  spec.version      = "1.0.0"
  spec.summary      = "广告"
  spec.description  = "广告管理"
  spec.homepage     = "https://github.com/fallpine/QSAdManager"
  spec.license      = "MIT (example)"
  spec.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  spec.author             = { "QiuSongChen" => "791589545@qq.com" }
  spec.platform     = :ios, "15.0"
  spec.source       = { :git => "https://github.com/fallpine/QSAdManager.git", :tag => "#{spec.version}" }
  spec.swift_version = '5'
  spec.source_files  = "QSAdManager/QSAdManager/Tool/*.{swift}"
  spec.dependency "Google-Mobile-Ads-SDK", "13.1.0"
  spec.dependency "SkeletonView", "1.30.4"
  spec.dependency "SnapKit", "5.7.1"

end
