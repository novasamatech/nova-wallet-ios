source 'https://cdn.cocoapods.org/'
platform :ios, '13.0'

abstract_target 'novawalletAll' do
  use_frameworks!

  pod 'SubstrateSdk', :git => 'https://github.com/nova-wallet/substrate-sdk-ios.git', :tag => '1.16.1'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'SoraKeystore', '~> 1.0.0'
  pod 'SoraUI', :git => 'https://github.com/ERussel/UIkit-iOS.git', :tag => '1.12.0'
  pod 'RobinHood', '~> 2.6.0'
  pod 'SoraFoundation', :git => 'https://github.com/ERussel/Foundation-iOS.git', :tag => '1.1.0'
  pod 'SwiftyBeaver'
  pod 'ReachabilitySwift'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  pod 'Kingfisher', :inhibit_warnings => true
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :tag => '3.0.0'
  pod 'SwiftRLP', :git => 'https://github.com/ERussel/SwiftRLP.git'
  pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :tag => '4.0.8'
  pod 'CDMarkdownKit', :git => 'https://github.com/nova-wallet/CDMarkdownKit.git', :tag => '2.5.2'
  pod 'web3swift', :git => 'https://github.com/web3swift-team/web3swift.git', :tag => '3.0.6'
  pod 'WalletConnectSwiftV2', :git => 'https://github.com/WalletConnect/WalletConnectSwiftV2.git', :tag => '1.5.14'
  pod 'EthereumSignTypedDataUtil', :git => 'https://github.com/ERussel/EthereumSignTypedDataUtil.git', :tag => '0.1.3'
  pod 'SwiftAlgorithms', '~> 1.0.0'
  pod 'ZMarkupParser', '= 1.6.1'
  pod 'FirebaseAuth'
  pod 'FirebaseFirestore'
  
  target 'novawalletTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'SubstrateSdk', :git => 'https://github.com/nova-wallet/substrate-sdk-ios.git', :tag => '1.16.1'
    pod 'SoraFoundation', :git => 'https://github.com/ERussel/Foundation-iOS.git', :tag => '1.1.0'
    pod 'R.swift', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', '~> 1.0.0'
    pod 'RobinHood', '~> 2.6.0'
    pod 'Sourcery', '~> 1.4'
    pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :tag => '4.0.8'

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
  
  installer.target_installation_results.pod_target_installation_results.each do |pod_name, target_installation_result|
    target_installation_result.resource_bundle_targets.each do |resource_bundle_target|
      resource_bundle_target.build_configurations.each do |config|
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      end
    end
  end

end
