import Foundation

extension GlobalConfigProvider {
    static let shared = GlobalConfigProvider(
        configUrl: ApplicationConfig.shared.globalConfigURL,
        mirrorHostChecker: ConfigMirrorHostChecker(
            mirrorBaseURL: ApplicationConfig.shared.configMirrorBaseURL,
            logger: Logger.shared
        )
    )
}
