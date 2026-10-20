import Foundation
import Keystore_iOS
import NovaAnalytics
import NovaAuth
import Operation_iOS

enum AnalyticsFacadeFactory {
    /// An accessor, not a builder. The only place in the app that touches the singleton, so
    /// every call site shares one lock, one call store, one session and one queue.
    static func createDefault() -> AnalyticsServiceFacadeProtocol {
        guard !EnviromentVariables.isUnitTesting else {
            return NoOpAnalyticsServiceFacade.shared
        }

        // Without an App ID prefix or App Attest support nothing this install attests can be
        // accepted, so analytics stays off rather than registering under an identity the gateway
        // will refuse.
        guard let sharedFacade else {
            Logger.shared.warning("No App ID prefix or no App Attest support; analytics stays disabled")

            return NoOpAnalyticsServiceFacade.shared
        }

        return sharedFacade
    }

    private static let sharedFacade: AnalyticsServiceFacadeProtocol? = {
        let settingsManager = SettingsManager.shared

        guard NovaAuthFacade.shared.isSupported else {
            return nil
        }

        return AnalyticsServiceFacade(
            configuration: AnalyticsConfiguration(
                authProvider: NovaAuthFacade.shared,
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

extension NovaAuthFacade: AnalyticsAuthProvidingProtocol {
    func createAuthWrapper() -> CompoundOperationWrapper<AnalyticsAuth> {
        let endpoint = createEndpointWrapper()
        let map = ClosureOperation<AnalyticsAuth> {
            let value = try endpoint.targetOperation.extractNoCancellableResultData()
            return AnalyticsAuth(context: value.context, client: value.client)
        }
        map.addDependency(endpoint.targetOperation)
        return endpoint.insertingTail(operation: map)
    }
}
