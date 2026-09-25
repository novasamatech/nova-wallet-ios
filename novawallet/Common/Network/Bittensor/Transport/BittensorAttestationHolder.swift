import Foundation
import Keystore_iOS
import NovaAppAttest
import Operation_iOS

struct BittensorAttestationContext {
    let baseURL: URL
    let provider: BackendAttestationProviderProtocol
}

protocol BittensorAttestationHolderProtocol: AnyObject {
    func createContextWrapper() -> CompoundOperationWrapper<BittensorAttestationContext>
}

enum BittensorAttestationStorageKey {
    static let clientId = "bittensorAttestationClientId"
    static let appAttestKeys = "bittensorAppAttestKeys"
}

final class BittensorAttestationHolder {
    private let configProvider: GlobalConfigProviding
    private let appAttest: AppAttestServiceProtocol
    private let appIdentity: AppAttestAppIdentity?
    private let isUnitTesting: Bool
    private let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue
    private let mutex = NSLock()

    private var context: BittensorAttestationContext?

    init(
        configProvider: GlobalConfigProviding,
        appAttest: AppAttestServiceProtocol,
        appIdentity: AppAttestAppIdentity?,
        isUnitTesting: Bool,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.configProvider = configProvider
        self.appAttest = appAttest
        self.appIdentity = appIdentity
        self.isUnitTesting = isUnitTesting
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
    }
}

extension BittensorAttestationHolder: BittensorAttestationHolderProtocol {
    func createContextWrapper() -> CompoundOperationWrapper<BittensorAttestationContext> {
        guard !isUnitTesting, let appIdentity else {
            return .createWithError(BittensorApiError.unsupportedDevice)
        }

        let mode = BackendAttestationModeResolver.resolve(isAppAttestSupported: appAttest.isSupported)

        guard mode == .appAttest else {
            return .createWithError(BittensorApiError.unsupportedDevice)
        }

        if let resolvedContext {
            return .createWithResult(resolvedContext)
        }

        let configWrapper = configProvider.createConfigWrapper()

        let contextOperation = ClosureOperation<BittensorAttestationContext> { [weak self] in
            let infraURL: URL

            do {
                infraURL = try configWrapper.targetOperation.extractNoCancellableResultData().infraUrl
            } catch {
                throw BittensorApiError.transport(error)
            }

            guard let self else {
                throw BittensorApiError.configuration
            }

            return buildContext(infraURL: infraURL, mode: mode, appIdentity: appIdentity)
        }

        contextOperation.addDependency(configWrapper.targetOperation)

        return configWrapper.insertingTail(operation: contextOperation)
    }
}

private extension BittensorAttestationHolder {
    var resolvedContext: BittensorAttestationContext? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return context
    }

    func buildContext(
        infraURL: URL,
        mode: BackendAttestationMode,
        appIdentity: AppAttestAppIdentity
    ) -> BittensorAttestationContext {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let context {
            return context
        }

        let identity = BackendAttestationIdentity(
            settingsManager: settingsManager,
            storageKey: BittensorAttestationStorageKey.clientId
        )

        let repository = SettingsAppAttestKeyRepository(
            settingsManager: settingsManager,
            storageKey: BittensorAttestationStorageKey.appAttestKeys
        )

        let provider = BackendAttestationProvider(
            appAttest: appAttest,
            remoteFactory: BackendAttestationRemoteFactory(baseURL: infraURL),
            identity: identity,
            repository: AnyDataProviderRepository(repository),
            gatewayURL: infraURL,
            mode: mode,
            appIdentity: appIdentity,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let builtContext = BittensorAttestationContext(baseURL: infraURL, provider: provider)

        context = builtContext

        return builtContext
    }
}
