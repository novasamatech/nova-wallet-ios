import Foundation
import Keystore_iOS
import NovaAnalytics
import NovaAppAttest

enum AnalyticsFacadeFactory {
    /// An accessor, not a builder. The only place in the app that touches the singleton, so
    /// every call site shares one lock, one call store, one session and one queue.
    ///
    /// The `-UNITTEST` check mirrors `AppDelegate.isUnitTesting`. Without it, every
    /// `xcodebuild test` run builds the real facade, which opens the developer's actual store,
    /// records a session and POSTs to the live gateway.
    static func createDefault() -> AnalyticsServiceFacadeProtocol {
        guard !ProcessInfo.processInfo.arguments.contains("-UNITTEST") else {
            return NoOpAnalyticsServiceFacade.shared
        }

        // Without an App ID prefix nothing this install attests can be accepted, so analytics
        // stays off rather than registering under an identity the gateway will refuse.
        guard let sharedFacade else {
            Logger.shared.warning("No App ID prefix in this build; analytics stays disabled")

            return NoOpAnalyticsServiceFacade.shared
        }

        return sharedFacade
    }

    private static let sharedFacade: AnalyticsServiceFacadeProtocol? = {
        let settingsManager = SettingsManager.shared

        guard let appIdentity = ApplicationConfig.shared.appAttestAppIdentity else {
            return nil
        }

        return AnalyticsServiceFacade(
            configuration: AnalyticsConfiguration(
                infraURLProvider: AnalyticsInfraURLAdapter(),
                appIdentity: appIdentity,
                appAttestService: AppAttestService(),
                // `ApplicationConfig.version` appends the build number, which the
                // gateway does not expect.
                appVersion: Bundle.main
                    .infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                storeDirectory: UserStorageParams.sharedStorageDirectoryURL,
                isFirstLaunch: { settingsManager.isAppFirstLaunch },
                settingsManager: settingsManager,
                logger: Logger.shared,
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                analyticsOperationQueue: OperationManagerFacade.analyticsQueue
            )
        )
    }()
}
