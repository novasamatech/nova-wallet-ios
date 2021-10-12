platform :ios, '11.0'

abstract_target 'fearlessAll' do
  use_frameworks!

  pod 'FearlessUtils', :git => 'https://github.com/nova-wallet/substrate-sdk-ios.git', :commit => '5ecdc0776b3d109a9ee830bf8b19adc1b95344b3'
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'SoraKeystore', '~> 1.0.0'
  pod 'SoraUI', '~> 1.10.3'
  pod 'RobinHood', '~> 2.6.0'
  pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '4133ff9b81cda094dd8e2b7f32129172224b0227'
  pod 'SoraFoundation', '~> 1.0.0'
  pod 'SwiftyBeaver'
  pod 'Starscream', :git => 'https://github.com/ERussel/Starscream.git', :branch => 'feature/without-origin'
  pod 'ReachabilitySwift'
  pod 'SnapKit', '~> 5.0.0'
  pod 'SwiftFormat/CLI', '~> 0.47.13'
  pod 'Sourcery', '~> 1.4'
  pod 'Kingfisher', :inhibit_warnings => true
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :tag => '3.0.0'
  pod 'keccak.c'
  pod 'IrohaCrypto', :git => 'https://github.com/ERussel/IrohaCrypto.git', :commit => 'b9df3717bee59169d1e8296f4e625c69c018cab7'
  pod 'Charts'

  target 'fearlessTests' do
    inherit! :search_paths

    pod 'Cuckoo'
    pod 'FearlessUtils', :git => 'https://github.com/nova-wallet/substrate-sdk-ios.git', :commit => '5ecdc0776b3d109a9ee830bf8b19adc1b95344b3'
    pod 'SoraFoundation', '~> 1.0.0'
    pod 'R.swift', :inhibit_warnings => true
    pod 'FireMock', :inhibit_warnings => true
    pod 'SoraKeystore', '~> 1.0.0'
    pod 'RobinHood', '~> 2.6.0'
    pod 'CommonWallet/Core', :git => 'https://github.com/soramitsu/Capital-iOS.git', :commit => '4133ff9b81cda094dd8e2b7f32129172224b0227'
    pod 'Sourcery', '~> 1.4'
    pod 'IrohaCrypto', :git => 'https://github.com/ERussel/IrohaCrypto.git', :commit => 'b9df3717bee59169d1e8296f4e625c69c018cab7'
    pod 'keccak.c'

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
