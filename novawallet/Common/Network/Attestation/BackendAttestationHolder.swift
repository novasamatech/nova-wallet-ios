import Foundation
import Keystore_iOS
import NovaAppAttest
import Operation_iOS

struct BackendAttestationEndpoint {
    let gatewayURL: URL
    let provider: BackendAttestationProviderProtocol
}

protocol BackendAttestationHolderProtocol: AnyObject {
    var exchangeGate: BackendAttestationExchangeGate { get }

    func createEndpointWrapper() -> CompoundOperationWrapper<BackendAttestationEndpoint>
}

final class BackendAttestationHolder {
    let exchangeGate: BackendAttestationExchangeGate

    private let configProvider: GlobalConfigProviding
    private let appAttest: AppAttestServiceProtocol
    private let appIdentity: AppAttestAppIdentity?
    private let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue
    private let mutex = NSLock()

    private var endpoint: BackendAttestationEndpoint?

    init(
        configProvider: GlobalConfigProviding,
        appAttest: AppAttestServiceProtocol,
        appIdentity: AppAttestAppIdentity?,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.configProvider = configProvider
        self.appAttest = appAttest
        self.appIdentity = appIdentity
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue

        exchangeGate = BackendAttestationExchangeGate(operationQueue: operationQueue)
    }
}

extension BackendAttestationHolder: BackendAttestationHolderProtocol {
    func createEndpointWrapper() -> CompoundOperationWrapper<BackendAttestationEndpoint> {
        guard let appIdentity else {
            return .createWithError(BackendAttestationError.unsupported)
        }

        if let resolvedEndpoint {
            return .createWithResult(resolvedEndpoint)
        }

        let configWrapper = configProvider.createConfigWrapper()

        let endpointOperation = ClosureOperation<BackendAttestationEndpoint> { [weak self] in
            let gatewayURL = try configWrapper.targetOperation.extractNoCancellableResultData().infraUrl

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            return buildEndpoint(gatewayURL: gatewayURL, appIdentity: appIdentity)
        }

        endpointOperation.addDependency(configWrapper.targetOperation)

        return configWrapper.insertingTail(operation: endpointOperation)
    }
}

extension BackendAttestationHolder {
    static let shared = BackendAttestationHolder(
        configProvider: GlobalConfigProvider.shared,
        appAttest: AppAttestService(),
        appIdentity: ApplicationConfig.shared.appAttestAppIdentity,
        settingsManager: SettingsManager.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue
    )
}

private extension BackendAttestationHolder {
    var resolvedEndpoint: BackendAttestationEndpoint? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return endpoint
    }

    func buildEndpoint(gatewayURL: URL, appIdentity: AppAttestAppIdentity) -> BackendAttestationEndpoint {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let endpoint {
            return endpoint
        }

        let provider = BackendAttestationProvider(
            appAttest: appAttest,
            remoteFactory: BackendAttestationRemoteFactory(baseURL: gatewayURL),
            identity: BackendAttestationIdentity(settingsManager: settingsManager),
            repository: AnyDataProviderRepository(SettingsAppAttestKeyRepository(settingsManager: settingsManager)),
            gatewayURL: gatewayURL,
            mode: BackendAttestationModeResolver.resolve(isAppAttestSupported: appAttest.isSupported),
            appIdentity: appIdentity,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let builtEndpoint = BackendAttestationEndpoint(gatewayURL: gatewayURL, provider: provider)

        endpoint = builtEndpoint

        return builtEndpoint
    }
}
