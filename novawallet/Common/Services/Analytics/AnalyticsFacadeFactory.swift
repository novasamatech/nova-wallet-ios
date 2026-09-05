import Foundation
import Keystore_iOS
import NovaAnalytics

enum AnalyticsFacadeFactory {
    /// An accessor, not a builder. The only place in the app that touches the singleton, so
    /// every call site shares one lock, one call store, one session and one queue.
    ///
    /// The `-UNITTEST` check mirrors `AppDelegate.isUnitTesting`. Without it, enabling
    /// `F_ANALYTICS` for Debug makes every `xcodebuild test` run build the real facade,
    /// which opens the developer's actual store, records a session and POSTs to the live
    /// gateway.
    static func createDefault() -> AnalyticsServiceFacadeProtocol {
        #if F_ANALYTICS
            guard !ProcessInfo.processInfo.arguments.contains("-UNITTEST") else {
                return NoOpAnalyticsServiceFacade.shared
            }

            return sharedFacade
        #else
            return NoOpAnalyticsServiceFacade.shared
        #endif
    }

    #if F_ANALYTICS
        private static let sharedFacade: AnalyticsServiceFacadeProtocol = {
            #if F_RELEASE
                let isReleaseBuild = true
            #else
                let isReleaseBuild = false
            #endif

            let settingsManager = SettingsManager.shared

            return AnalyticsServiceFacade(
                configuration: AnalyticsConfiguration(
                    gatewayURL: ApplicationConfig.shared.gatewayURL,
                    // `ApplicationConfig.version` appends the build number, which the
                    // gateway does not expect.
                    appVersion: Bundle.main
                        .infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                    storeDirectory: UserStorageParams.sharedStorageDirectoryURL,
                    isReleaseBuild: isReleaseBuild,
                    isFirstLaunch: { settingsManager.isAppFirstLaunch },
                    settingsManager: settingsManager,
                    remoteSettings: AnalyticsRemoteSettingsAdapter(),
                    logger: Logger.shared,
                    operationQueue: OperationManagerFacade.sharedDefaultQueue,
                    analyticsOperationQueue: OperationManagerFacade.analyticsQueue
                )
            )
        }()
    #endif
}
