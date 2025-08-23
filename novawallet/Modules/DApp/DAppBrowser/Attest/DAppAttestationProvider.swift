import Foundation
import Operation_iOS

protocol DAppAttestationProviderProtocol {
    func createAttestWrapper(
        for baseURL: String,
        with bodyDataClosure: @escaping () throws -> Data?
    ) -> CompoundOperationWrapper<DAppAssertionCallFactory>
}

final class DAppAttestationProvider {
    private let appAttestService: AppAttestServiceProtocol
    private let remoteAttestationFactory: DAppRemoteAttestFactoryProtocol
    private let attestationRepository: AnyDataProviderRepository<AppAttestBrowserSettings>
    private let operationQueue: OperationQueue
    private let syncQueue: DispatchQueue
    private let bundle: Bundle
    private let logger: LoggerProtocol

    private let attestationCancellable = CancellableCallStore()

    private var attestedKeyId: AppAttestKeyId?
    private var pendingRequests: [UUID: PendingRequest] = [:]
    private var pendingAssertions: [UUID: CancellableCallStore] = [:]

    init(
        appAttestService: AppAttestServiceProtocol,
        remoteAttestationFactory: DAppRemoteAttestFactoryProtocol,
        attestationRepository: AnyDataProviderRepository<AppAttestBrowserSettings>,
        operationQueue: OperationQueue,
        bundle: Bundle = Bundle.main,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.appAttestService = appAttestService
        self.remoteAttestationFactory = remoteAttestationFactory
        self.attestationRepository = attestationRepository
        self.operationQueue = operationQueue
        syncQueue = DispatchQueue(label: "io.novawallet.dappattestationprovider.\(UUID().uuidString)")
        self.bundle = bundle
        self.logger = logger
    }
}

// MARK: - Private

private extension DAppAttestationProvider {
    func saveLocalSettingsWrapper(
        _ settingsClosure: @escaping () throws -> AppAttestBrowserSettings
    ) -> CompoundOperationWrapper<Void> {
        let saveOperation = attestationRepository.saveOperation({
            let settings = try settingsClosure()
            return [settings]
        }, { [] })

        return CompoundOperationWrapper(targetOperation: saveOperation)
    }

    func loadAttestationIfNeeded(using baseURL: String) {
        guard !attestationCancellable.hasCall, attestedKeyId == nil else {
            return
        }

        guard appAttestService.isSupported else {
            logger.warning("Attestation is not supported")
            return
        }

        let settingsOperation = loadLocalSettingsOperation(for: baseURL)

        let attestationWrapper = OperationCombiningService<AppAttestKeyId>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let settings = try settingsOperation.extractNoCancellableResultData()

            guard let settings, settings.isAttested else {
                return self.createAttestationWrapper(for: settings?.keyId, baseURLString: baseURL)
            }

            return CompoundOperationWrapper.createWithResult(settings.keyId)
        }

        attestationWrapper.addDependency(operations: [settingsOperation])

        let totalWrapper = attestationWrapper.insertingHead(operations: [settingsOperation])

        logger.debug("Will start attestation")

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: attestationCancellable,
            runningCallbackIn: syncQueue
        ) { [weak self] result in
            switch result {
            case let .success(keyId):
                self?.logger.debug("Attestation succeeded")
                self?.attestedKeyId = keyId
                self?.handleResolved(keyId: keyId, baseURL: baseURL)
            case let .failure(error):
                self?.logger.debug("Attestation failed: \(error)")
                self?.handleAttestation(error: error, baseURL: baseURL)
            }
        }
    }

    func handleResolved(
        keyId: AppAttestKeyId,
        baseURL: String
    ) {
        let allRequests = pendingRequests
        pendingRequests = [:]

        allRequests.forEach { requestId, request in
            fetchAssertion(
                for: requestId,
                bodyData: request.bodyData,
                baseURLString: baseURL,
                keyId: keyId,
                runningCompletionIn: request.queue,
                completion: request.resultClosure
            )
        }
    }

    func handleAttestation(
        error: Error,
        baseURL: String
    ) {
        checkErrorAndDiscardKeyIfNeeded(error, baseURLString: baseURL)

        let allRequests = pendingRequests.values
        pendingRequests = [:]

        allRequests.forEach { request in
            request.queue.async {
                request.resultClosure(.failure(error))
            }
        }
    }

    func createAttestationWrapper(
        for keyId: AppAttestKeyId?,
        baseURLString: String
    ) -> CompoundOperationWrapper<AppAttestKeyId> {
        guard let baseURL = URL(string: baseURLString) else {
            return .createWithError(AppAttestError.invalidURL)
        }

        let challengeWrapper = remoteAttestationFactory.createGetChallengeWrapper(using: baseURL)

        let attestationWrapper = appAttestService.createAttestationWrapper(
            for: {
                try challengeWrapper.targetOperation.extractNoCancellableResultData()
            },
            using: keyId
        )

        attestationWrapper.addDependency(wrapper: challengeWrapper)

        let attestationInitSaveWrapper = saveLocalSettingsWrapper {
            let appAttestModel = try attestationWrapper.targetOperation.extractNoCancellableResultData()
            return AppAttestBrowserSettings(
                baseURL: baseURLString,
                keyId: appAttestModel.keyId,
                isAttested: false
            )
        }

        attestationInitSaveWrapper.addDependency(wrapper: attestationWrapper)

        let remoteAttestationOperation = remoteAttestationFactory.createAttestationOperation(
            using: baseURL
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }
            guard let bundleId = bundle.bundleIdentifier else {
                throw AppAttestServiceError.bundleIdUnavailable
            }

            try attestationInitSaveWrapper.targetOperation.extractNoCancellableResultData()

            let attestationModel = try attestationWrapper.targetOperation.extractNoCancellableResultData()

            return DAppAttestRequest(
                challenge: attestationModel.challenge.toHexString(),
                attestation: attestationModel.result,
                appIntegrityId: attestationModel.keyId,
                bundleId: bundleId
            )
        }

        remoteAttestationOperation.addDependency(attestationInitSaveWrapper.targetOperation)

        let attestationSaveIfSuccessWrapper = saveLocalSettingsWrapper {
            _ = try remoteAttestationOperation.extractNoCancellableResultData()

            let attestationModel = try attestationWrapper.targetOperation.extractNoCancellableResultData()

            return AppAttestBrowserSettings(
                baseURL: baseURLString,
                keyId: attestationModel.keyId,
                isAttested: true
            )
        }

        attestationSaveIfSuccessWrapper.addDependency(operations: [remoteAttestationOperation])

        let resultOperation = ClosureOperation<AppAttestKeyId> {
            _ = try attestationSaveIfSuccessWrapper.targetOperation.extractNoCancellableResultData()
            let attestationModel = try attestationWrapper.targetOperation.extractNoCancellableResultData()

            return attestationModel.keyId
        }

        resultOperation.addDependency(attestationSaveIfSuccessWrapper.targetOperation)

        let preSaveDependencies = challengeWrapper.allOperations
            + attestationWrapper.allOperations
            + attestationInitSaveWrapper.allOperations
        let remoteDependencies = [remoteAttestationOperation]
            + attestationSaveIfSuccessWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: preSaveDependencies + remoteDependencies
        )
    }

    func loadLocalSettingsOperation(for baseURL: String) -> BaseOperation<AppAttestBrowserSettings?> {
        attestationRepository.fetchOperation(
            by: { baseURL },
            options: .init()
        )
    }

    func fetchAssertion(
        for requestId: UUID,
        bodyData: Data?,
        baseURLString: String,
        keyId: AppAttestKeyId,
        runningCompletionIn queue: DispatchQueue,
        completion: @escaping (Result<DAppAssertionCallFactory, Error>) -> Void
    ) {
        guard let baseURL = URL(string: baseURLString) else {
            return
        }

        let callStore = CancellableCallStore()
        pendingAssertions[requestId] = callStore

        let challengeWrapper = remoteAttestationFactory.createGetChallengeWrapper(using: baseURL)
        let assertionWrapper = appAttestService.createAssertionWrapper(
            challengeClosure: { try challengeWrapper.targetOperation.extractNoCancellableResultData() },
            dataClosure: { bodyData },
            keyId: keyId
        )

        assertionWrapper.addDependency(wrapper: challengeWrapper)

        let totalWrapper = assertionWrapper.insertingHead(operations: challengeWrapper.allOperations)

        logger.debug("Will start assertion: \(requestId)")

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: syncQueue
        ) { [weak self] result in
            self?.pendingAssertions[requestId] = nil

            switch result {
            case let .success(model):
                self?.logger.debug("Assertion succeeded: \(requestId)")

                queue.async {
                    completion(.success(AppAttestAssertionModelResult.supported(model)))
                }
            case let .failure(error):
                self?.logger.debug("Assertion failed: \(error)")
                self?.checkErrorAndDiscardKeyIfNeeded(error, baseURLString: baseURLString)

                queue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func doAssertion(
        for requestId: UUID,
        for baseURLString: String,
        bodyData: Data?,
        queue: DispatchQueue,
        completion: @escaping (Result<DAppAssertionCallFactory, Error>) -> Void
    ) {
        guard appAttestService.isSupported else {
            queue.async {
                completion(.success(AppAttestAssertionModelResult.unsupported))
            }
            return
        }

        if let attestedKeyId {
            fetchAssertion(
                for: requestId,
                bodyData: bodyData,
                baseURLString: baseURLString,
                keyId: attestedKeyId,
                runningCompletionIn: queue,
                completion: completion
            )
        } else {
            pendingRequests[requestId] = .init(
                resultClosure: completion,
                bodyData: bodyData,
                queue: queue
            )
            loadAttestationIfNeeded(using: baseURLString)
        }
    }

    func checkErrorAndDiscardKeyIfNeeded(
        _ error: Error,
        baseURLString: String
    ) {
        if
            let serviceError = error as? AppAttestServiceError,
            case .invalidKeyId = serviceError {
            let removeOperation = attestationRepository.saveOperation(
                { [] },
                { [baseURLString] }
            )

            execute(
                operation: removeOperation,
                inOperationQueue: operationQueue,
                runningCallbackIn: syncQueue
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.attestedKeyId = nil
                case let .failure(error):
                    self?.logger.error("Unexpected error: \(error)")
                }
            }
        }
    }

    func cancelAssertion(for requestId: UUID) {
        pendingRequests[requestId] = nil
        pendingAssertions[requestId]?.cancel()
        pendingAssertions[requestId] = nil
    }
}

// MARK: - DAppAttestationProviderProtocol

extension DAppAttestationProvider: DAppAttestationProviderProtocol {
    func createAttestWrapper(
        for baseURL: String,
        with bodyDataClosure: @escaping () throws -> Data?
    ) -> CompoundOperationWrapper<DAppAssertionCallFactory> {
        let requestId = UUID()

        let operation = AsyncClosureOperation<DAppAssertionCallFactory>(
            operationClosure: { [weak self] completion in
                let bodyData = try bodyDataClosure()

                self?.syncQueue.async {
                    self?.doAssertion(
                        for: requestId,
                        for: baseURL,
                        bodyData: bodyData,
                        queue: .global(),
                        completion: completion
                    )
                }
            },
            cancelationClosure: { [weak self] in
                self?.syncQueue.async {
                    self?.cancelAssertion(for: requestId)
                }
            }
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

// MARK: - Private types

private extension DAppAttestationProvider {
    struct PendingRequest {
        let resultClosure: (Result<DAppAssertionCallFactory, Error>) -> Void
        let bodyData: Data?
        let queue: DispatchQueue
    }
}
