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
    ///
    /// `AnalyticsDebugInspecting` rides along in the return type only so
    /// `AnalyticsDebugInspectorViewController` (`F_DEV`) need not downcast. It is a separate
    /// protocol precisely so the package's production contract does not carry it; both
    /// facades conform unconditionally, so nothing here is configuration-dependent.
    static func createDefault() -> AnalyticsServiceFacadeProtocol & AnalyticsDebugInspecting {
        #if F_ANALYTICS
            guard !ProcessInfo.processInfo.arguments.contains("-UNITTEST") else {
                return NoOpAnalyticsServiceFacade.shared
            }

            return sharedFacade
        #else
            return NoOpAnalyticsServiceFacade.shared
        #endif
    }

    /// Read outside `#if F_ANALYTICS` on purpose: nested inside it, the `true` branch
    /// type-checks in no configuration at all, because `F_ANALYTICS` is defined only for
    /// `debug`/`dev` and `F_RELEASE` only for `release`/`staging`. This is the flag that
    /// picks the attestation ladder the day analytics ships in Release, so both branches
    /// must compile everywhere.
    #if F_RELEASE
        private static let isReleaseBuild = true
    #else
        private static let isReleaseBuild = false
    #endif

    #if F_ANALYTICS
        private static let sharedFacade: AnalyticsServiceFacadeProtocol & AnalyticsDebugInspecting = {
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
