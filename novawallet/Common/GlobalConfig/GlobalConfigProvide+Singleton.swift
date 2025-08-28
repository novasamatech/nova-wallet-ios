import Foundation

extension GlobalConfigProvider {
    static let shared = GlobalConfigProvider(
        configUrl: ApplicationConfig.shared.globalConfigURL
    )
}
