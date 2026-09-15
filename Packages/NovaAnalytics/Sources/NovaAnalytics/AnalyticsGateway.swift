import Foundation
import Operation_iOS
import Keystore_iOS
import SDKLogger
import NovaAppAttest
import NovaOperationSupport

struct AnalyticsGateway {
    let attestation: BackendAttestationProviderProtocol
    let uploadFactory: AnalyticsUploadOperationFactoryProtocol
}

protocol AnalyticsGatewayResolving: AnyObject {
    func createGatewayWrapper() -> CompoundOperationWrapper<AnalyticsGateway>

    func forgetClient()
    func allowClient()
}

final class AnalyticsGatewayResolver: AnalyticsGatewayResolving {
    private let infraURLProvider: AnalyticsInfraURLProviding
    private let appAttest: AppAttestServiceProtocol
    private let attestationMode: BackendAttestationMode
    private let appIdentity: AppAttestAppIdentity
    private let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue
    private let logger: SDKLoggerProtocol
    private let identity: BackendAttestationIdentityProtocol
    private let keyRepository: AnyDataProviderRepository<AppAttestKeySettings>

    private let mutex = NSLock()
    private var gateway: AnalyticsGateway?

    init(
        infraURLProvider: AnalyticsInfraURLProviding,
        appAttest: AppAttestServiceProtocol,
        attestationMode: BackendAttestationMode,
        appIdentity: AppAttestAppIdentity,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        logger: SDKLoggerProtocol
    ) {
        self.infraURLProvider = infraURLProvider
        self.appAttest = appAttest
        self.attestationMode = attestationMode
        self.appIdentity = appIdentity
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.logger = logger

        identity = BackendAttestationIdentity(settingsManager: settingsManager)
        keyRepository = AnyDataProviderRepository(
            SettingsAppAttestKeyRepository(settingsManager: settingsManager)
        )
    }

    var resolved: AnalyticsGateway? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return gateway
    }

    func createGatewayWrapper() -> CompoundOperationWrapper<AnalyticsGateway> {
        if let resolved {
            return .createWithResult(resolved)
        }

        let urlWrapper = infraURLProvider.createInfraURLWrapper()

        let mapOperation = ClosureOperation<AnalyticsGateway> { [weak self] in
            let infraURL = try urlWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            return build(infraURL: infraURL)
        }

        mapOperation.addDependency(urlWrapper.targetOperation)

        return urlWrapper.insertingTail(operation: mapOperation)
    }
}

// MARK: - Consent lifecycle

extension AnalyticsGatewayResolver {
    func forgetClient() {
        guard let resolved else {
            identity.forgetClientId()

            deleteAllStoredKeys()

            return
        }

        resolved.attestation.forgetClient()
    }

    func allowClient() {
        guard let resolved else {
            if let clientId = identity.existingClientId() {
                identity.resetClientId(ifCurrent: clientId)
            }

            identity.allowCreation()

            deleteAllStoredKeys()

            return
        }

        resolved.attestation.allowClient()
    }
}

// MARK: - Private

private extension AnalyticsGatewayResolver {
    func deleteAllStoredKeys() {
        execute(
            wrapper: CompoundOperationWrapper(targetOperation: keyRepository.deleteAllOperation()),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Analytics attest key wipe failed: \(error)")
            }
        }
    }

    func build(infraURL: URL) -> AnalyticsGateway {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let gateway {
            return gateway
        }

        let attestation = BackendAttestationProvider(
            appAttest: appAttest,
            remoteFactory: BackendAttestationRemoteFactory(baseURL: infraURL),
            identity: identity,
            repository: keyRepository,
            gatewayURL: infraURL,
            mode: attestationMode,
            appIdentity: appIdentity,
            operationQueue: operationQueue,
            logger: logger
        )

        let built = AnalyticsGateway(
            attestation: attestation,
            uploadFactory: AnalyticsUploadOperationFactory(baseURL: infraURL, logger: logger)
        )

        gateway = built

        return built
    }
}
