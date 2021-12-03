platform :ios, '11.0'

abstract_target 'novawalletAll' do
  use_frameworks!

  pod 'SubstrateSdk', :git => 'https://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@github.com/nova-wallet/substrate-sdk-ios.git', :commit => '1443ece967d1c6b7bb9a7a9636f6fe7ab34531ff'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'SoraKeystore', '~> 1.0.0'
  pod 'SoraUI', '~> 1.10.3'
  pod 'RobinHood', '~> 2.6.0'
  pod 'CommonWallet/Core', :git => 'https://github.com/ERussel/Capital-iOS.git', :commit => '450b0c80adda8765914ec9abaca9b6602254af1d'
  pod 'SoraFoundation', '~> 1.0.0'
  pod 'SwiftyBeaver'
  pod 'ReachabilitySwift'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  pod 'Kingfisher', :inhibit_warnings => true
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :tag => '3.0.0'
  pod 'Charts'

  target 'novawalletTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'SubstrateSdk', :git => 'https://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@github.com/nova-wallet/substrate-sdk-ios.git', :commit => '450b0c80adda8765914ec9abaca9b6602254af1d'
    pod 'SoraFoundation', '~> 1.0.0'
    pod 'R.swift', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', '~> 1.0.0'
    pod 'RobinHood', '~> 2.6.0'
    pod 'CommonWallet/Core', :git => 'https://github.com/ERussel/Capital-iOS.git', :commit => 'efdfc58791144ede8a8de994fb48f563f55dda1f'
    pod 'Sourcery', '~> 1.4'

  end

  target 'novawalletIntegrationTests'

  target 'novawallet'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
    end
  end
end
