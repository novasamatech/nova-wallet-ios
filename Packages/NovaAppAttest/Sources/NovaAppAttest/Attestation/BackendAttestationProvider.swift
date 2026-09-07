import Foundation
import Operation_iOS
import NovaOperationSupport
import SDKLogger

/// Holds one attested App Attest key per (gateway, clientId) row. It is re-minted on a launch's first
/// invalid-identifier report, generic attestKey failure and events-endpoint rejection, and on a consent cycle, which
/// lifts the process-wide gateway rejection and the events-endpoint latch but not the two Apple brakes. A gateway
/// client or server error, serviceUnavailable and a repeat generic attestKey failure open the persisted backoff
/// on an un-attested row; anything else, a repeat invalid-identifier report included, waits on the flush schedule.
public final class BackendAttestationProvider {
    private let appAttest: AppAttestServiceProtocol
    private let remoteFactory: BackendAttestationRemoteFactoryProtocol
    private let identity: BackendAttestationIdentityProtocol
    private let repository: AnyDataProviderRepository<AppAttestKeySettings>
    private let gatewayURL: URL
    private let mode: BackendAttestationMode
    private let bundle: Bundle
    private let operationQueue: OperationQueue
    private let logger: SDKLoggerProtocol
    private let timeProvider: () -> Date

    private let mutex = NSLock()

    private var attestedKeyId: AppAttestKeyId?
    private var rejectedForProcess: Bool = false
    private var invalidKeyIdDiscardedThisLaunch: Bool = false
    private var attestationGenericDiscardedThisLaunch: Bool = false
    private var unattestedMarkedThisLaunch: Bool = false

    private var needsFreshKey: Bool = false

    public init(
        appAttest: AppAttestServiceProtocol,
        remoteFactory: BackendAttestationRemoteFactoryProtocol,
        identity: BackendAttestationIdentityProtocol,
        repository: AnyDataProviderRepository<AppAttestKeySettings>,
        gatewayURL: URL,
        mode: BackendAttestationMode,
        bundle: Bundle = .main,
        operationQueue: OperationQueue,
        logger: SDKLoggerProtocol,
        timeProvider: @escaping () -> Date = { Date() }
    ) {
        self.appAttest = appAttest
        self.remoteFactory = remoteFactory
        self.identity = identity
        self.repository = repository
        self.gatewayURL = gatewayURL
        self.mode = mode
        self.bundle = bundle
        self.operationQueue = operationQueue
        self.logger = logger
        self.timeProvider = timeProvider
    }
}

/// The row a running chain owns, so the failure handler never asks the identity for a client id —
/// that call mints one.
private struct AttestationChainContext {
    let rowIdentifier: String
    let epoch: Int
}

private final class AttestationChainContextBox {
    private let mutex = NSLock()
    private var stored: AttestationChainContext?

    var value: AttestationChainContext? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return stored
    }

    func store(_ context: AttestationChainContext) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stored = context
    }
}

// MARK: - State

private extension BackendAttestationProvider {
    /// Each trigger owns its own per-launch discard, so one spending its brake cannot silence another.
    enum DiscardBrake {
        case invalidKeyId
        case attestationGeneric
    }

    enum Constants {
        static let platform = "ios"
        static let attestationType = "app_attest"
        static let rejectedStatusCode = 403
        static let baseBackoff: TimeInterval = 60
        static let maxBackoff: TimeInterval = 86400
    }

    func rowIdentifier(for clientId: String) -> String {
        gatewayURL.absoluteString + "|" + clientId
    }

    func backoffInterval(for attemptCount: Int) -> TimeInterval {
        guard attemptCount > 1 else {
            return Constants.baseBackoff
        }

        let scaled = Constants.baseBackoff * pow(2, Double(attemptCount - 1))

        return min(scaled, Constants.maxBackoff)
    }

    /// The window is an absolute persisted date, so a clock moved backwards would wedge attestation for
    /// the whole shift; nothing this class wrote can sit further out than one full backoff.
    func isBackoffActive(until nextAttemptAt: Date) -> Bool {
        let now = timeProvider()

        return nextAttemptAt > now && nextAttemptAt <= now.addingTimeInterval(Constants.maxBackoff)
    }

    func cachedAttestedKeyId() -> AppAttestKeyId? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return needsFreshKey ? nil : attestedKeyId
    }

    func resolveRow(_ stored: AppAttestKeySettings?) -> AppAttestKeySettings? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard needsFreshKey else {
            return stored
        }

        needsFreshKey = false

        return nil
    }

    func requireEpoch(_ epoch: Int) throws {
        guard identity.consentEpoch == epoch else {
            throw BackendAttestationError.unsupported
        }
    }

    func cacheAttestedKeyId(_ keyId: AppAttestKeyId) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        attestedKeyId = keyId
        needsFreshKey = false
    }

    /// Both consent transitions mint an identity the gateway has never rejected, so its latches start over.
    /// Apple's verdict on a key describes the device, not the identity, so those brakes stay launch scoped.
    func clearGatewayBrakes() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        rejectedForProcess = false
        unattestedMarkedThisLaunch = false
    }

    func deleteRow(_ identifier: String) {
        let operation = repository.saveOperation({ [] }, { [identifier] })

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Attestation key row delete failed: \(error)")
            }
        }
    }

    /// A no-op on an attested row: the gate stops reading `nextAttemptAt` once a key is attested, so a
    /// window there would only inflate `attemptCount`. The uploader's flush schedule is the brake there.
    func applyBackoff(_ context: AttestationChainContext) {
        let identifier = context.rowIdentifier

        let fetchOperation = repository.fetchOperation(
            by: { identifier },
            options: RepositoryFetchOptions()
        )

        let saveOperation = repository.saveOperation({ [weak self] in
            guard
                let self,
                let row = try fetchOperation.extractNoCancellableResultData(),
                !row.isAttested
            else {
                return []
            }

            try requireEpoch(context.epoch)

            let attemptCount = row.attemptCount + 1

            return [
                AppAttestKeySettings(
                    identifier: row.identifier,
                    keyId: row.keyId,
                    isAttested: row.isAttested,
                    attemptCount: attemptCount,
                    nextAttemptAt: timeProvider().addingTimeInterval(backoffInterval(for: attemptCount))
                )
            ]
        }, { [] })

        saveOperation.addDependency(fetchOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [fetchOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Attestation backoff write failed: \(error)")
            }
        }
    }

    func discardRowOnce(_ context: AttestationChainContext, brake: DiscardBrake) -> Bool {
        mutex.lock()

        let shouldDiscard: Bool

        switch brake {
        case .invalidKeyId:
            shouldDiscard = !invalidKeyIdDiscardedThisLaunch
            invalidKeyIdDiscardedThisLaunch = true
        case .attestationGeneric:
            shouldDiscard = !attestationGenericDiscardedThisLaunch
            attestationGenericDiscardedThisLaunch = true
        }

        if shouldDiscard {
            attestedKeyId = nil
            needsFreshKey = true
        }

        mutex.unlock()

        guard shouldDiscard else {
            return false
        }

        deleteRow(context.rowIdentifier)

        return true
    }

    func handleFailure(_ error: Error, context: AttestationChainContext?) {
        if let attestationError = error as? BackendAttestationError, case .rejected = attestationError {
            mutex.lock()
            rejectedForProcess = true
            attestedKeyId = nil
            mutex.unlock()

            logger.warning("Gateway rejected this client; attestation short-circuits until relaunch")

            return
        }

        guard let context else {
            return
        }

        if let serviceError = error as? AppAttestServiceError {
            handleAppleFailure(serviceError, context: context)
        } else if let attestationError = error as? BackendAttestationError {
            handleGatewayFailure(attestationError, context: context)
        }
    }

    func handleAppleFailure(_ error: AppAttestServiceError, context: AttestationChainContext) {
        switch error {
        case .invalidKeyId:
            _ = discardRowOnce(context, brake: .invalidKeyId)
        case .attestationGeneric:
            if !discardRowOnce(context, brake: .attestationGeneric) {
                applyBackoff(context)
            }
        case .serviceUnavailable:
            applyBackoff(context)
        case .keyIdGeneration, .assertionGeneric:
            break
        }
    }

    func handleGatewayFailure(_ error: BackendAttestationError, context: AttestationChainContext) {
        switch error {
        case .clientError, .serverError:
            applyBackoff(context)
        case .rejected, .retryLater, .unsupported, .invalidResponse:
            break
        }
    }
}

// MARK: - Chain

private extension BackendAttestationProvider {
    func createHeadersWrapper(
        bodyClosure: @escaping () throws -> Data,
        contextBox: AttestationChainContextBox
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        mutex.lock()
        let isRejected = rejectedForProcess
        mutex.unlock()

        guard !isRejected else {
            return .createWithError(
                BackendAttestationError.rejected(statusCode: Constants.rejectedStatusCode)
            )
        }

        switch mode {
        case .none:
            return .createWithResult(nil)
        case .unavailable:
            return .createWithError(BackendAttestationError.unsupported)
        case .appAttest:
            break
        }

        let epoch = identity.consentEpoch

        guard let clientId = identity.clientId(), identity.consentEpoch == epoch else {
            return .createWithError(BackendAttestationError.unsupported)
        }

        let context = AttestationChainContext(
            rowIdentifier: rowIdentifier(for: clientId),
            epoch: epoch
        )

        contextBox.store(context)

        return createSignedChainWrapper(
            clientId: clientId,
            context: context,
            bodyClosure: bodyClosure
        )
    }

    func createSignedChainWrapper(
        clientId: String,
        context: AttestationChainContext,
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let attestedWrapper = ensureAttestedWrapper(clientId: clientId, context: context)

        let challengeWrapper = OperationCombiningService<String>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, remoteFactory] in
            _ = try attestedWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return remoteFactory.createChallengeWrapper()
        }

        challengeWrapper.addDependency(wrapper: attestedWrapper)

        let assertionWrapper = OperationCombiningService<AppAttestAssertion>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, appAttest] in
            let keyId = try attestedWrapper.targetOperation.extractNoCancellableResultData()
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return appAttest.createAssertionWrapper(keyId: keyId) {
                let body = try bodyClosure()

                return AttestationClientData.assertionClientData(
                    challenge: challenge,
                    clientId: clientId,
                    body: body
                )
            }
        }

        assertionWrapper.addDependency(wrapper: challengeWrapper)

        let mapOperation = ClosureOperation<[AttestationHeaderKey: String]?> {
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()
            let assertion = try assertionWrapper.targetOperation.extractNoCancellableResultData()

            return [
                .clientId: clientId,
                .challenge: challenge,
                .signature: assertion.base64EncodedString()
            ]
        }

        mapOperation.addDependency(assertionWrapper.targetOperation)

        return assertionWrapper
            .insertingHead(operations: attestedWrapper.allOperations + challengeWrapper.allOperations)
            .insertingTail(operation: mapOperation)
    }

    func ensureAttestedWrapper(
        clientId: String,
        context: AttestationChainContext
    ) -> CompoundOperationWrapper<AppAttestKeyId> {
        let identifier = context.rowIdentifier

        let fetchOperation = repository.fetchOperation(
            by: { identifier },
            options: RepositoryFetchOptions()
        )

        let wrapper = OperationCombiningService<AppAttestKeyId>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BackendAttestationError.unsupported
            }

            if let cached = cachedAttestedKeyId() {
                return .createWithResult(cached)
            }

            let row = try resolveRow(fetchOperation.extractNoCancellableResultData())

            if let row, row.isAttested {
                cacheAttestedKeyId(row.keyId)

                return .createWithResult(row.keyId)
            }

            if let nextAttemptAt = row?.nextAttemptAt, isBackoffActive(until: nextAttemptAt) {
                throw BackendAttestationError.retryLater(until: nextAttemptAt)
            }

            try requireEpoch(context.epoch)

            return createAttestAndRegisterWrapper(
                clientId: clientId,
                context: context,
                existingKeyId: row?.keyId
            )
        }

        wrapper.addDependency(operations: [fetchOperation])

        return wrapper.insertingHead(operations: [fetchOperation])
    }

    func createAttestAndRegisterWrapper(
        clientId: String,
        context: AttestationChainContext,
        existingKeyId: AppAttestKeyId?
    ) -> CompoundOperationWrapper<AppAttestKeyId> {
        let keyIdWrapper = createKeyIdWrapper(context: context, existingKeyId: existingKeyId)

        let challengeWrapper = OperationCombiningService<String>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, remoteFactory] in
            _ = try keyIdWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return remoteFactory.createChallengeWrapper()
        }

        challengeWrapper.addDependency(wrapper: keyIdWrapper)

        let attestationWrapper = createAttestationWrapper(
            clientId: clientId,
            context: context,
            keyIdWrapper: keyIdWrapper,
            challengeWrapper: challengeWrapper
        )

        attestationWrapper.addDependency(wrapper: challengeWrapper)

        let registerOperation = createRegisterOperation(
            clientId: clientId,
            context: context,
            challengeWrapper: challengeWrapper,
            attestationWrapper: attestationWrapper
        )

        registerOperation.addDependency(attestationWrapper.targetOperation)

        let saveAttestedOperation = createSaveOperation(isAttested: true, context: context) {
            try registerOperation.extractNoCancellableResultData()

            return try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId
        }

        saveAttestedOperation.addDependency(registerOperation)

        let mapOperation = createCacheOperation(
            context: context,
            attestationWrapper: attestationWrapper,
            saveOperation: saveAttestedOperation
        )

        mapOperation.addDependency(saveAttestedOperation)

        let dependencies = keyIdWrapper.allOperations + challengeWrapper.allOperations +
            attestationWrapper.allOperations + [registerOperation, saveAttestedOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    /// Apple offers no way to look a key identifier up again, so a freshly minted one is written
    /// before it is attested — otherwise a failed attestation orphans a production key for good.
    func createKeyIdWrapper(
        context: AttestationChainContext,
        existingKeyId: AppAttestKeyId?
    ) -> CompoundOperationWrapper<AppAttestKeyId> {
        if let existingKeyId {
            return .createWithResult(existingKeyId)
        }

        let generationOperation = appAttest.createKeyGenerationOperation()

        let saveOperation = createSaveOperation(isAttested: false, context: context) {
            try generationOperation.extractNoCancellableResultData()
        }

        saveOperation.addDependency(generationOperation)

        let mapOperation = ClosureOperation<AppAttestKeyId> {
            try saveOperation.extractNoCancellableResultData()

            return try generationOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(saveOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [generationOperation, saveOperation]
        )
    }

    func createAttestationWrapper(
        clientId: String,
        context: AttestationChainContext,
        keyIdWrapper: CompoundOperationWrapper<AppAttestKeyId>,
        challengeWrapper: CompoundOperationWrapper<String>
    ) -> CompoundOperationWrapper<AppAttestAttestation> {
        OperationCombiningService<AppAttestAttestation>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, appAttest] in
            let keyId = try keyIdWrapper.targetOperation.extractNoCancellableResultData()
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return appAttest.createAttestationWrapper(using: keyId) { attestingKeyId in
                AttestationClientData.attestationClientData(
                    challenge: challenge,
                    clientId: clientId,
                    keyId: attestingKeyId
                )
            }
        }
    }

    func createRegisterOperation(
        clientId: String,
        context: AttestationChainContext,
        challengeWrapper: CompoundOperationWrapper<String>,
        attestationWrapper: CompoundOperationWrapper<AppAttestAttestation>
    ) -> BaseOperation<Void> {
        let appPackage = bundle.bundleIdentifier ?? ""

        return remoteFactory.createRegisterOperation { [weak self] in
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()
            let attestation = try attestationWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return BackendAttestationRegisterRequest(
                clientId: clientId,
                platform: Constants.platform,
                appPackage: appPackage,
                attestationType: Constants.attestationType,
                keyId: attestation.keyId,
                challenge: challenge,
                integrityToken: attestation.attestation.base64EncodedString()
            )
        }
    }

    func createCacheOperation(
        context: AttestationChainContext,
        attestationWrapper: CompoundOperationWrapper<AppAttestAttestation>,
        saveOperation: BaseOperation<Void>
    ) -> BaseOperation<AppAttestKeyId> {
        ClosureOperation<AppAttestKeyId> { [weak self] in
            try saveOperation.extractNoCancellableResultData()

            let keyId = try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            cacheAttestedKeyId(keyId)

            return keyId
        }
    }

    func createSaveOperation(
        isAttested: Bool,
        context: AttestationChainContext,
        keyIdClosure: @escaping () throws -> AppAttestKeyId
    ) -> BaseOperation<Void> {
        let identifier = context.rowIdentifier

        return repository.saveOperation({ [weak self] in
            let keyId = try keyIdClosure()

            guard let self else {
                return []
            }

            try requireEpoch(context.epoch)

            return [
                AppAttestKeySettings(
                    identifier: identifier,
                    keyId: keyId,
                    isAttested: isAttested,
                    attemptCount: 0,
                    nextAttemptAt: nil
                )
            ]
        }, { [] })
    }
}

// MARK: - BackendAttestationProviderProtocol

extension BackendAttestationProvider: BackendAttestationProviderProtocol {
    public func createSignedHeadersWrapper(
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let contextBox = AttestationChainContextBox()

        let wrapper = OperationCombiningService<[AttestationHeaderKey: String]?>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BackendAttestationError.unsupported
            }

            return createHeadersWrapper(bodyClosure: bodyClosure, contextBox: contextBox)
        }

        let resultOperation = ClosureOperation<[AttestationHeaderKey: String]?> { [weak self] in
            do {
                return try wrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                self?.handleFailure(error, context: contextBox.value)

                throw error
            }
        }

        resultOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: resultOperation)
    }

    public func markUnattested() {
        guard let clientId = identity.existingClientId() else {
            logger.warning("Events endpoint refused the assertion while no client id was stored")

            return
        }

        mutex.lock()
        let shouldDiscard = !unattestedMarkedThisLaunch

        if shouldDiscard {
            unattestedMarkedThisLaunch = true
            attestedKeyId = nil
            needsFreshKey = true
        }

        mutex.unlock()

        guard shouldDiscard else {
            logger.warning("Events endpoint refused the assertion again; keeping the key until relaunch")

            return
        }

        deleteRow(rowIdentifier(for: clientId))
    }

    public func forgetClient() {
        let clientId = identity.existingClientId()

        mutex.lock()
        attestedKeyId = nil
        needsFreshKey = true
        mutex.unlock()

        clearGatewayBrakes()

        identity.forgetClientId()

        guard let clientId else {
            return
        }

        deleteRow(rowIdentifier(for: clientId))
    }

    public func allowClient() {
        identity.allowCreation()

        clearGatewayBrakes()
    }
}
