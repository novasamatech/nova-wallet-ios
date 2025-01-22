source 'https://cdn.cocoapods.org/'
platform :ios, '14.0'

abstract_target 'novawalletAll' do
  use_frameworks!

  pod 'DSF_QRCode', '~> 18.0.0'
  pod 'SubstrateSdk', :git => 'https://github.com/nova-wallet/substrate-sdk-ios.git', :tag => '3.5.0'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'SoraKeystore', '~> 1.0.0'
  pod 'SoraUI', :git => 'https://github.com/ERussel/UIkit-iOS.git', :tag => '1.14.0'
  pod 'Operation-iOS', :git => 'https://github.com/novasamatech/Operation-iOS', :tag => '2.1.0'
  pod 'SoraFoundation', :git => 'https://github.com/ERussel/Foundation-iOS.git', :tag => '1.1.0'
  pod 'SwiftyBeaver'
  pod 'ReachabilitySwift', '~> 5.2.4'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  pod 'Kingfisher', :inhibit_warnings => true
  pod 'SwiftDraw', '~> 0.18.0'
  pod 'SwiftRLP', :git => 'https://github.com/ERussel/SwiftRLP.git'
  pod 'Starscream', :git => 'https://github.com/novasamatech/Starscream.git', :tag => '4.0.12'
  pod 'CDMarkdownKit', :git => 'https://github.com/nova-wallet/CDMarkdownKit.git', :tag => '2.5.2'
  pod 'web3swift', :git => 'https://github.com/web3swift-team/web3swift.git', :tag => '3.0.6'
  pod 'WalletConnectSwiftV2', :git => 'https://github.com/novasamatech/WalletConnectSwiftV2.git', :tag => 'rc1.9.6'
  pod 'EthereumSignTypedDataUtil', :git => 'https://github.com/ERussel/EthereumSignTypedDataUtil.git', :tag => '0.1.3'
  pod 'SwiftAlgorithms', '~> 1.0.0'
  pod 'ZMarkupParser', '= 1.6.1'
  pod 'FirebaseAuth', '~> 11.3.0'
  pod 'FirebaseFirestore', '~> 11.3.0'
  pod 'FirebaseMessaging', '~> 11.3.0'
  pod 'FirebaseAppCheck', '~> 11.3.0'
  pod 'HydraMath', :git => 'https://github.com/novasamatech/hydra-math-swift.git', :tag => '0.2'
  pod 'MetadataShortenerApi', :git => 'https://github.com/novasamatech/metadata-shortener-ios.git', :tag => '0.1.0'
  pod 'IrohaCrypto', :git => 'https://github.com/novasamatech/IrohaCrypto', :tag => '0.9.1'
  pod 'secp256k1.c', :git => 'https://github.com/novasamatech/secp256k1.c', :tag => '0.1.3'
  
  target 'novawalletTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'SubstrateSdk', :git => 'https://github.com/nova-wallet/substrate-sdk-ios.git', :tag => '3.5.0'
    pod 'SoraFoundation', :git => 'https://github.com/ERussel/Foundation-iOS.git', :tag => '1.1.0'
    pod 'R.swift', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', '~> 1.0.0'
    pod 'Operation-iOS', :git => 'https://github.com/novasamatech/Operation-iOS', :tag => '2.1.0'
    pod 'Sourcery', '~> 1.4'
    pod 'Starscream', :git => 'https://github.com/novasamatech/Starscream.git', :tag => '4.0.12'
    pod 'HydraMath', :git => 'https://github.com/novasamatech/hydra-math-swift.git', :tag => '0.2'
    pod 'MetadataShortenerApi', :git => 'https://github.com/novasamatech/metadata-shortener-ios.git', :tag => '0.1.0'
    pod 'IrohaCrypto', :git => 'https://github.com/novasamatech/IrohaCrypto', :tag => '0.9.1'
    pod 'secp256k1.c', :git => 'https://github.com/novasamatech/secp256k1.c', :tag => '0.1.3'
  end

  target 'novawalletIntegrationTests'

  target 'novawallet'
  
  target 'NovaPushNotificationServiceExtension' do
    inherit! :search_paths

    pod 'SwiftLint'
    pod 'R.swift', :inhibit_warnings => true
    pod 'SoraFoundation', :git => 'https://github.com/ERussel/Foundation-iOS.git', :tag => '1.1.0'
    pod 'SoraKeystore', '~> 1.0.0'
    pod 'Operation-iOS', :git => 'https://github.com/novasamatech/Operation-iOS', :tag => '2.1.0'
    pod 'Sourcery', '~> 1.4'
    pod 'SubstrateSdk', :git => 'https://github.com/nova-wallet/substrate-sdk-ios.git', :tag => '3.5.0'
    pod 'SwiftyBeaver'
    pod 'IrohaCrypto', :git => 'https://github.com/novasamatech/IrohaCrypto', :tag => '0.9.1'
    pod 'secp256k1.c', :git => 'https://github.com/novasamatech/secp256k1.c', :tag => '0.1.3'
  end


end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
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
