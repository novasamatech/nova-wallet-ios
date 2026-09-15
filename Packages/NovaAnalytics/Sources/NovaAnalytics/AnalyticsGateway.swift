import Foundation
import Operation_iOS
import Keystore_iOS
import SDKLogger
import NovaAppAttest
import NovaOperationSupport

/// The pair of collaborators that can only be built once the infra URL is known.
struct AnalyticsGateway {
    let attestation: BackendAttestationProviderProtocol
    let uploadFactory: AnalyticsUploadOperationFactoryProtocol
}

protocol AnalyticsGatewayResolving: AnyObject {
    func createGatewayWrapper() -> CompoundOperationWrapper<AnalyticsGateway>

    func forgetClient()
    func allowClient()
}

/// Builds the gateway once, on first use, from the remotely published infra URL.
///
/// Both collaborators bind to that URL — the attestation key row is keyed on it and the request
/// targets are hashed into the assertion — so neither can exist before it resolves. The instance
/// is memoised because `BackendAttestationProvider` carries per-process state (the attested key,
/// the rejection latch and the re-mint brakes) that a rebuilt instance would forget.
final class AnalyticsGatewayResolver: AnalyticsGatewayResolving {
    private let infraURLProvider: AnalyticsInfraURLProviding
    private let appAttest: AppAttestServiceProtocol
    private let attestationMode: BackendAttestationMode
    private let appIdentity: AppAttestAppIdentity
    private let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue
    private let logger: SDKLoggerProtocol

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
    }

    /// The gateway if it has already been built, for callers that cannot wait on a fetch.
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

/// These run on consent changes, which must take effect whether or not the gateway has ever been
/// built. Everything they touch — the attestation identity and the stored key rows — is keyed off
/// settings alone, so an unresolved gateway is handled directly rather than forcing a fetch.
extension AnalyticsGatewayResolver {
    func forgetClient() {
        guard let resolved else {
            let identity = makeIdentity()

            // Forget first: the wipe below spares the current row, so there must not be one.
            identity.forgetClientId()

            deleteAllStoredKeys()

            return
        }

        resolved.attestation.forgetClient()
    }

    func allowClient() {
        guard let resolved else {
            let identity = makeIdentity()

            if let clientId = identity.existingClientId() {
                identity.resetClientId(ifCurrent: clientId)
            }

            identity.allowCreation()

            return
        }

        resolved.attestation.allowClient()
    }
}

// MARK: - Private

private extension AnalyticsGatewayResolver {
    func makeIdentity() -> BackendAttestationIdentityProtocol {
        BackendAttestationIdentity(settingsManager: settingsManager)
    }

    func deleteAllStoredKeys() {
        let repository = AnyDataProviderRepository(
            SettingsAppAttestKeyRepository(settingsManager: settingsManager)
        )

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let deleteOperation = repository.saveOperation({ [] }, {
            try fetchOperation.extractNoCancellableResultData().map(\.identifier)
        })

        deleteOperation.addDependency(fetchOperation)

        operationQueue.addOperations([fetchOperation, deleteOperation], waitUntilFinished: false)
    }

    func build(infraURL: URL) -> AnalyticsGateway {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        // A concurrent chain may have won the race; keep that instance so its state is not lost.
        if let gateway {
            return gateway
        }

        let attestation = BackendAttestationProvider(
            appAttest: appAttest,
            remoteFactory: BackendAttestationRemoteFactory(baseURL: infraURL),
            identity: BackendAttestationIdentity(settingsManager: settingsManager),
            repository: AnyDataProviderRepository(
                SettingsAppAttestKeyRepository(settingsManager: settingsManager)
            ),
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
