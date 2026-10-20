import Foundation
import Operation_iOS

public final class NovaAuth: NovaAuthClientProtocol {
    let dependencies: NovaAuthDependencies
    let bootstrap: NovaAuthBootstrapOperationFactory
    let gate = NSLock()
    var state: NovaAuthInstallationState?
    var storageFailed = false
    var tokenCache: NovaAuthTokenRecord?

    private var pendingStateWrite: NovaAuthInstallationState?
    var flight: NovaAuthIssuanceFlight?
    var issuanceCooldown = NovaAuthCooldown()
    var originCooldown = NovaAuthCooldown()
    var rejectedCredentials = NovaAuthRejectedCredentials()

    public convenience init(configuration: NovaAuthConfiguration) {
        let clock = NovaAuthContinuousClock()
        let http = NovaAuthHTTPTransport()
        self.init(dependencies: NovaAuthDependencies(
            appAttest: NovaAuthDeviceCheckService(),
            identityStore: NovaAuthSettingsIdentityStore(settingsManager: configuration.settingsManager),
            tokenStore: NovaAuthKeychainTokenStore(service: configuration.keychainService),
            clock: clock, random: NovaAuthSystemRandom(),
            http: http,
            ownerQueue: configuration.ownerQueue, bootstrapQueue: configuration.bootstrapQueue,
            requestQueue: configuration.requestQueue, appIdentity: configuration.appIdentity,
            logger: configuration.logger
        ))
    }

    init(dependencies: NovaAuthDependencies) {
        self.dependencies = dependencies
        bootstrap = NovaAuthBootstrapOperationFactory(http: dependencies.http, clock: dependencies.clock)
    }

    public var isSupported: Bool {
        dependencies.appAttest.isSupported
    }

    public static func removeLegacyBearer(keychainService: String) throws {
        guard let namespace = Bundle.main.bundleIdentifier else { return }
        try NovaAuthKeychainTokenStore.removeLegacyRecord(service: keychainService, namespace: namespace)
    }

    public func activate(origin: NovaAuthOrigin) throws -> NovaAuthContext {
        try gate.novaAuthLocked {
            do {
                try loadStateIfNeeded()
            } catch is NovaAuthIdentityStoreError {
                try repairCorruptState(origin: origin)
            }
            try retryStorageWork()
            if let state, state.context.origin == origin {
                return state.context
            }
            if state != nil { return try replaceContext(origin: origin) }
            let initial = NovaAuthInstallationState(
                version: 1,
                context: NovaAuthContext(origin: origin, generation: 1),
                identity: nil
            )
            try persist(initial)
            return initial.context
        }
    }

    public func createAdmissionWrapper(
        in context: NovaAuthContext
    ) -> CompoundOperationWrapper<Void> {
        let operation = NovaAuthWaiterOperation<Void> { [self] cancellation, completion in
            demand(context: context, intent: .userDriven, cancellation: cancellation) { result in
                completion(result.map { _ in () })
            }
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    public func createResponseWrapper(
        for request: NovaAuthRequest,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        NovaAuthAuthorizedOperationFactory(owner: self).createWrapper(request: request, beforeSend: beforeSend)
    }

    func validate(context: NovaAuthContext) throws {
        guard !storageFailed else { throw NovaAuthError.storageUnavailable }
        guard state?.context == context else { throw NovaAuthError.generationChanged }
    }

    func persist(_ newState: NovaAuthInstallationState) throws {
        state = newState
        pendingStateWrite = newState
        do {
            try dependencies.identityStore.save(newState)
            pendingStateWrite = nil
        } catch {
            storageFailed = true
            throw NovaAuthError.storageUnavailable
        }
    }

    func retryStorageWork() throws {
        do {
            if let pendingStateWrite {
                try dependencies.identityStore.save(pendingStateWrite)
                self.pendingStateWrite = nil
            }
            if var replacement = state, replacement.tokenRemovalOwed == true {
                try removeAllTokens()
                replacement.tokenRemovalOwed = nil
                try persist(replacement)
            }
            storageFailed = false
        } catch {
            storageFailed = true
            throw NovaAuthError.storageUnavailable
        }
    }

    func setIdentity(_ identity: NovaAuthInstallationIdentity, context: NovaAuthContext) throws {
        try validate(context: context)
        let replacement = NovaAuthInstallationState(
            version: 1, context: context, identity: identity, tokenRemovalOwed: state?.tokenRemovalOwed
        )
        try persist(replacement)
    }

    func setRegistration(_ registration: NovaAuthRegistrationState, flight: NovaAuthIssuanceFlight) throws {
        guard let identity = state?.identity else { throw NovaAuthError.keyUnavailable }
        try setIdentity(NovaAuthInstallationIdentity(
            clientID: identity.clientID,
            keyID: identity.keyID,
            registration: registration,
            refusal: registration == .registered ? nil : identity.refusal,
            keyCreatedAt: identity.keyCreatedAt
        ), context: flight.context)
    }

    func enqueue(_ action: @escaping () -> Void) {
        dependencies.ownerQueue.addOperation(action)
    }

    func run<Value>(
        _ wrapper: CompoundOperationWrapper<Value>,
        flight: NovaAuthIssuanceFlight,
        completion: @escaping (Result<Value, Error>) throws -> Void
    ) {
        flight.cancelChild = { wrapper.cancel() }
        let target = wrapper.targetOperation
        let configuration = target.configurationBlock
        target.configurationBlock = { [self, weak target] in
            configuration?()
            do {
                try gate.novaAuthLocked {
                    guard self.flight === flight else { throw NovaAuthError.cancelled }
                    try validate(context: flight.context)
                }
            } catch { target?.result = .failure(Self.safeError(error)) }
        }
        target.completionBlock = { [self, weak target] in
            let result = target?.result ?? .failure(NovaAuthError.cancelled)
            target?.completionBlock = nil
            enqueue { [self] in
                gate.novaAuthLocked {
                    guard self.flight === flight else { return }
                    flight.cancelChild = nil
                    do {
                        try validate(context: flight.context)
                        try completion(result)
                    } catch { fail(error, flight: flight) }
                }
            }
        }
        dependencies.bootstrapQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func beforeBootstrapSend(
        flight: NovaAuthIssuanceFlight,
        step: BootstrapStep
    ) throws {
        try gate.novaAuthLocked {
            guard self.flight === flight else { throw NovaAuthError.cancelled }
            try validate(context: flight.context)
            let now = try dependencies.clock.now()
            if step == .registration {
                try setRegistration(.registrationPending(NovaAuthPendingRegistration(startedAt: now)), flight: flight)
            }
            if step == .tokenChallenge { try reservePendingProbe(flight: flight, now: now) }
            if step == .token { flight.issuanceStart = now }
        }
    }

    func finish(_ result: Result<NovaAuthTokenRecord, Error>, flight: NovaAuthIssuanceFlight) {
        guard self.flight === flight else { return }
        self.flight = nil
        let callbacks = Array(flight.waiters.values)
        flight.waiters.removeAll()
        enqueue { [self] in
            for completion in callbacks {
                let delivery = gate.novaAuthLocked { () -> Result<NovaAuthTokenRecord, Error> in
                    guard state?.context == flight.context else { return .failure(NovaAuthError.generationChanged) }
                    return result
                }
                completion(delivery)
            }
        }
    }
}

private extension NovaAuth {
    func loadStateIfNeeded() throws {
        guard state == nil else { return }
        do {
            state = try dependencies.identityStore.load()
        } catch let error as NovaAuthIdentityStoreError {
            throw error
        } catch {
            storageFailed = true
            throw NovaAuthError.storageUnavailable
        }
    }

    func repairCorruptState(origin: NovaAuthOrigin) throws {
        let previous = try loadToken().flatMap { record -> UInt64? in
            guard (try? NovaAuthStoredValidation.token(record)) != nil else { return nil }
            return record.context.generation
        } ?? 0
        guard previous < UInt64.max else { throw NovaAuthError.invalidConfiguration }
        try persist(NovaAuthInstallationState(
            version: 1,
            context: NovaAuthContext(origin: origin, generation: previous + 1),
            identity: nil,
            tokenRemovalOwed: true
        ))
        try retryStorageWork()
    }

    func replaceContext(origin: NovaAuthOrigin) throws -> NovaAuthContext {
        let previous = state?.context.generation ?? 0
        guard previous < UInt64.max else { throw NovaAuthError.invalidConfiguration }
        let replacement = NovaAuthInstallationState(
            version: 1,
            context: NovaAuthContext(origin: origin, generation: previous + 1),
            identity: nil,
            tokenRemovalOwed: true
        )
        state = replacement
        storageFailed = false
        if let flight {
            let callbacks = Array(flight.waiters.values)
            flight.waiters.removeAll()
            self.flight = nil
            let cancelChild = flight.cancelChild
            flight.cancelChild = nil
            if !flight.irreversible { cancelChild?() }
            enqueue { callbacks.forEach { $0(.failure(NovaAuthError.generationChanged)) } }
        }
        issuanceCooldown.clear()
        originCooldown.clear()
        rejectedCredentials = NovaAuthRejectedCredentials()
        do {
            try persist(replacement)
            try retryStorageWork()
        } catch {
            storageFailed = true
            throw NovaAuthError.storageUnavailable
        }
        return replacement.context
    }
}

final class NovaAuthIssuanceFlight {
    let context: NovaAuthContext
    var waiters: [UUID: (Result<NovaAuthTokenRecord, Error>) -> Void] = [:]
    var cancelChild: (() -> Void)?
    var irreversible = false
    var issuanceStart: NovaAuthTime?
    var pendingProbeReserved = false
    var step: BootstrapStep = .registrationChallenge
    var generatedKey = false
    let sponsored: Bool

    init(context: NovaAuthContext, sponsored: Bool) {
        self.context = context
        self.sponsored = sponsored
    }
}

enum BootstrapStep: String {
    case registrationChallenge, keyGeneration, attestation, registration, tokenChallenge, assertion, token
}
