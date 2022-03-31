platform :ios, '13.0'

abstract_target 'novawalletAll' do
  use_frameworks!

  pod 'SubstrateSdk', :git => 'https://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@github.com/nova-wallet/substrate-sdk-ios.git', :commit => '16ebc9bedbf6eb58f9045b16bb31cddb90585059'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'SoraKeystore', '~> 1.0.0'
  pod 'SoraUI', :git => 'https://github.com/ERussel/UIkit-iOS.git', :commit => '5d364b42000925775361d2098276871e429bfc47'
  pod 'RobinHood', '= 2.6.0'
  pod 'CommonWallet/Core', :git => 'https://github.com/ERussel/Capital-iOS.git', :commit => 'da686d69620aea28dc1aef0fbaf322e2c4b5c84e'
  pod 'SoraFoundation', '~> 1.0.0'
  pod 'SwiftyBeaver', '~> 1.9.3'
  pod 'ReachabilitySwift'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  pod 'Kingfisher', '~> 6.3.0', :inhibit_warnings => true
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :tag => '3.0.0'
  pod 'Charts'
  pod 'SwiftRLP', :git => 'https://github.com/ERussel/SwiftRLP.git'
  pod 'Base58Swift', :git => 'https://github.com/keefertaylor/Base58Swift.git', :tag => '2.1.14'
  pod 'BeaconCore', :git => 'https://github.com/airgap-it/beacon-ios-sdk.git', :tag => '3.1.0'
  pod 'BeaconBlockchainSubstrate', :git => 'https://github.com/airgap-it/beacon-ios-sdk.git', :tag => '3.1.0'
  pod 'BeaconClientWallet', :git => 'https://github.com/airgap-it/beacon-ios-sdk.git', :tag => '3.1.0'
  pod 'BeaconTransportP2PMatrix', :git => 'https://github.com/airgap-it/beacon-ios-sdk.git', :tag => '3.1.0'
  pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :commit => '96b40350509663ecdbf82c8498b457303c6fc10d'

  target 'novawalletTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'SubstrateSdk', :git => 'https://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@github.com/nova-wallet/substrate-sdk-ios.git', :commit => '16ebc9bedbf6eb58f9045b16bb31cddb90585059'
    pod 'SoraFoundation', '~> 1.0.0'
    pod 'R.swift', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', '~> 1.0.0'
    pod 'RobinHood', '~> 2.6.0'
    pod 'CommonWallet/Core', :git => 'https://github.com/ERussel/Capital-iOS.git', :commit => 'da686d69620aea28dc1aef0fbaf322e2c4b5c84e'
    pod 'Sourcery', '~> 1.4'
    pod 'BeaconCore', :git => 'https://github.com/airgap-it/beacon-ios-sdk.git', :tag => '3.1.0'
    pod 'BeaconBlockchainSubstrate', :git => 'https://github.com/airgap-it/beacon-ios-sdk.git', :tag => '3.1.0'
    pod 'BeaconClientWallet', :git => 'https://github.com/airgap-it/beacon-ios-sdk.git', :tag => '3.1.0'
    pod 'BeaconTransportP2PMatrix', :git => 'https://github.com/airgap-it/beacon-ios-sdk.git', :tag => '3.1.0'
    pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :commit => '96b40350509663ecdbf82c8498b457303c6fc10d'

  end

  target 'novawalletIntegrationTests'

  target 'novawallet'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
