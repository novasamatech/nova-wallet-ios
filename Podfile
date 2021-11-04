platform :ios, '11.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'SubstrateSdk', :git => 'https://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@github.com/nova-wallet/substrate-sdk-ios.git', :commit => 'e643d2b04be1ffc4e752e4058298a9833368ca9e'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'SoraKeystore', '~> 1.0.0'
  pod 'SoraUI', '~> 1.10.3'
  pod 'RobinHood', '~> 2.6.0'
  pod 'CommonWallet/Core', :git => 'https://github.com/ERussel/Capital-iOS.git', :commit => '2f128c4d9f86d268748b8227e3e231bd6f786e35'
  pod 'SoraFoundation', '~> 1.0.0'
  pod 'SwiftyBeaver'
  pod 'ReachabilitySwift'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  pod 'Kingfisher', :inhibit_warnings => true
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :tag => '3.0.0'
  pod 'Charts'

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'SubstrateSdk', :git => 'https://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@github.com/nova-wallet/substrate-sdk-ios.git', :commit => 'e643d2b04be1ffc4e752e4058298a9833368ca9e'
    pod 'SoraFoundation', '~> 1.0.0'
    pod 'R.swift', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', '~> 1.0.0'
    pod 'RobinHood', '~> 2.6.0'
    pod 'CommonWallet/Core', :git => 'https://github.com/ERussel/Capital-iOS.git', :commit => '2f128c4d9f86d268748b8227e3e231bd6f786e35'
    pod 'Sourcery', '~> 1.4'

  end

  target 'fearlessIntegrationTests'

  target 'fearless'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
    end
  end
end
