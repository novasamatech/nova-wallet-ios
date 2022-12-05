source 'https://cdn.cocoapods.org/'
platform :ios, '13.0'

abstract_target 'novawalletAll' do
  use_frameworks!

  pod 'SubstrateSdk', :git => 'https://github.com/nova-wallet/substrate-sdk-ios.git', :commit => 'caa1c264e41d8ba5428db6c91b66a2d25154f341'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'SoraKeystore', '~> 1.0.0'
  pod 'SoraUI', :git => 'https://github.com/ERussel/UIkit-iOS.git', :tag => '1.11.1'
  pod 'RobinHood', '~> 2.6.0'
  pod 'CommonWallet/Core', :git => 'https://github.com/ERussel/Capital-iOS.git', :tag => '1.16.0'
  pod 'SoraFoundation', '~> 1.0.0'
  pod 'SwiftyBeaver'
  pod 'ReachabilitySwift'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  pod 'Kingfisher', :inhibit_warnings => true
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :tag => '3.0.0'
  pod 'Charts'
  pod 'SwiftRLP', :git => 'https://github.com/ERussel/SwiftRLP.git'
  pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :tag => '4.0.5'
  pod 'CDMarkdownKit', :git => 'https://github.com/nova-wallet/CDMarkdownKit.git', :tag => '2.4.0'
  pod 'web3swift', :git => 'https://github.com/web3swift-team/web3swift.git', :tag => '3.0.6'
  
  target 'novawalletTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'SubstrateSdk', :git => 'https://github.com/nova-wallet/substrate-sdk-ios.git', :commit => 'caa1c264e41d8ba5428db6c91b66a2d25154f341'
    pod 'SoraFoundation', '~> 1.0.0'
    pod 'R.swift', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', '~> 1.0.0'
    pod 'RobinHood', '~> 2.6.0'
    pod 'CommonWallet/Core', :git => 'https://github.com/ERussel/Capital-iOS.git', :tag => '1.16.0'
    pod 'Sourcery', '~> 1.4'
    pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :tag => '4.0.5'

  end

  target 'novawalletIntegrationTests'

  target 'novawallet'

end

post_install do |installer|
  dev_team = ""
  project = installer.aggregate_targets[0].user_project
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      if dev_team.empty? and !config.build_settings['DEVELOPMENT_TEAM'].nil?
        dev_team = config.build_settings['DEVELOPMENT_TEAM']
      end
    end
  end
end
