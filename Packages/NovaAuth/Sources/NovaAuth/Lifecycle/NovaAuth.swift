import Foundation
import Operation_iOS

public final class NovaAuth: NovaAuthClientProtocol {
    let dependencies: NovaAuthDependencies
    let gate = NSLock()
    var state: NovaAuthInstallationState?
    var storageFailed = false {
        didSet {
            if storageFailed, !oldValue {
                NovaAuthDiagnostics.log(.storageFailed, logger: dependencies.logger)
            }
        }
    }

    private var pendingStateWrite: NovaAuthInstallationState?
    private var invalidationID = UUID()
    var flight: NovaAuthIssuanceFlight?
    var issuanceCooldown = NovaAuthCooldown()
    var originCooldown = NovaAuthCooldown()
    var businessCooldowns = NovaAuthBusinessCooldowns()
    var rejectedCredentials = NovaAuthRejectedCredentials()

    public convenience init(configuration: NovaAuthConfiguration) {
        let clock = NovaAuthContinuousClock()
        let http = NovaAuthHTTPTransport()
        self.init(dependencies: NovaAuthDependencies(
            appAttest: NovaAuthDeviceCheckService(),
            identityStore: NovaAuthSettingsIdentityStore(settingsManager: configuration.settingsManager),
            tokenStore: NovaAuthKeychainTokenStore(configuration: configuration.sharedStore),
            clock: clock, random: NovaAuthSystemRandom(),
            bootstrap: NovaAuthBootstrapOperationFactory(http: http, clock: clock), http: http,
            ownerQueue: configuration.ownerQueue, bootstrapQueue: configuration.bootstrapQueue,
            requestQueue: configuration.requestQueue, appIdentity: configuration.appIdentity,
            logger: configuration.logger
        ))
    }

    init(dependencies: NovaAuthDependencies) {
        self.dependencies = dependencies
    }

    public var isSupported: Bool { dependencies.appAttest.isSupported }

    public var contextInvalidationID: UUID {
        gate.novaAuthLocked { invalidationID }
    }

    public func activate(origin: NovaAuthOrigin) throws -> NovaAuthContext {
        try gate.novaAuthLocked {
            do {
                try loadStateIfNeeded()
            } catch let error as NovaAuthIdentityStoreError {
                try repairCorruptState(origin: origin, requiresUserAction: error == .resetPending)
            }
            try retryStorageWork()
            if let state, state.context.origin == origin {
                return state.context
            }
            if state != nil { return try replaceContext(origin: origin) }
            let initial = NovaAuthInstallationState(
                version: 1,
                context: NovaAuthContext(origin: origin, generation: 1),
                requiresUserAction: false,
                identity: nil
            )
            try persist(initial)
            return initial.context
        }
    }

    public func reset() throws {
        try gate.novaAuthLocked {
            invalidationID = UUID()
            do {
                try loadStateIfNeeded()
            } catch is NovaAuthIdentityStoreError {
                do {
                    try dependencies.identityStore.markResetPending()
                    try dependencies.tokenStore.removeAll()
                    dependencies.http.clearReadCache()
                    storageFailed = false
                    return
                } catch { storageFailed = true; throw NovaAuthError.storageUnavailable }
            }
            let completingReset = storageFailed && state?.requiresUserAction == true && state?.identity == nil
            try retryStorageWork()
            if completingReset { return }
            if let origin = state?.context.origin {
                _ = try replaceContext(origin: origin)
            } else {
                do {
                    try dependencies.identityStore.markResetPending()
                    try dependencies.tokenStore.removeAll()
                    dependencies.http.clearReadCache()
                    storageFailed = false
                } catch {
                    storageFailed = true
                    throw NovaAuthError.storageUnavailable
                }
            }
        }
    }

    public func createAdmissionWrapper(
        in context: NovaAuthContext,
        intent: NovaAuthRequestIntent
    ) -> CompoundOperationWrapper<Void> {
        let operation = NovaAuthWaiterOperation<Void> { [self] cancellation, completion in
            demand(context: context, intent: intent, cancellation: cancellation) { result in
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

    func setIdentity(_ identity: NovaAuthInstallationIdentity, context: NovaAuthContext) throws {
        try validate(context: context)
        let replacement = NovaAuthInstallationState(
            version: 1, context: context, requiresUserAction: state?.requiresUserAction ?? false, identity: identity,
            recovery: state?.recovery, tokenRemovalOwed: state?.tokenRemovalOwed
        )
        try persist(replacement)
    }

    func setRegistration(_ registration: NovaAuthRegistrationState, flight: NovaAuthIssuanceFlight) throws {
        guard let identity = state?.identity else { throw NovaAuthError.keyUnavailable }
        try setIdentity(NovaAuthInstallationIdentity(
            clientID: identity.clientID,
            keyID: identity.keyID,
            registration: registration
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
        registration: Bool = false,
        probe: Bool = false,
        issuance: Bool = false
    ) throws {
        try gate.novaAuthLocked {
            guard self.flight === flight else { throw NovaAuthError.cancelled }
            try validate(context: flight.context)
            let now = try dependencies.clock.now()
            if registration {
                try setRegistration(.registrationPending(NovaAuthPendingRegistration(startedAt: now)), flight: flight)
            }
            if probe { try reservePendingProbe(flight: flight, now: now) }
            if issuance { flight.issuanceStart = now }
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

    func retryStorageWork() throws {
        do {
            if let pendingStateWrite {
                try dependencies.identityStore.save(pendingStateWrite)
                self.pendingStateWrite = nil
            }
            if var replacement = state, replacement.tokenRemovalOwed == true {
                try dependencies.tokenStore.removeAll()
                replacement.tokenRemovalOwed = nil
                try persist(replacement)
            }
            if storageFailed { NovaAuthDiagnostics.log(.storageRecovery, logger: dependencies.logger) }
            storageFailed = false
        } catch {
            storageFailed = true
            throw NovaAuthError.storageUnavailable
        }
    }

    func repairCorruptState(origin: NovaAuthOrigin, requiresUserAction: Bool) throws {
        invalidationID = UUID()
        let record: NovaAuthTokenRecord?
        do { record = try dependencies.tokenStore.load() } catch { throw NovaAuthError.storageUnavailable }
        let previous = record.flatMap { record -> UInt64? in
            guard (try? NovaAuthStoredValidation.token(record)) != nil else { return nil }
            return record.context.generation
        } ?? 0
        guard previous < UInt64.max else { throw NovaAuthError.invalidConfiguration }
        dependencies.http.clearReadCache()
        try persist(NovaAuthInstallationState(
            version: 1,
            context: NovaAuthContext(origin: origin, generation: previous + 1),
            requiresUserAction: requiresUserAction,
            identity: nil,
            tokenRemovalOwed: true
        ))
        try retryStorageWork()
        NovaAuthDiagnostics.log(.storageRecovery, logger: dependencies.logger)
    }

    func replaceContext(origin: NovaAuthOrigin) throws -> NovaAuthContext {
        let previous = state?.context.generation ?? 0
        guard previous < UInt64.max else { throw NovaAuthError.invalidConfiguration }
        let replacement = NovaAuthInstallationState(
            version: 1,
            context: NovaAuthContext(origin: origin, generation: previous + 1),
            requiresUserAction: true,
            identity: nil,
            tokenRemovalOwed: true
        )
        // The memory fence must survive even a failed persistent reset.
        state = replacement
        invalidationID = UUID()
        storageFailed = false
        if let flight {
            let callbacks = Array(flight.waiters.values)
            flight.waiters.removeAll()
            self.flight = nil
            if !flight.irreversible { flight.cancelChild?() }
            enqueue { callbacks.forEach { $0(.failure(NovaAuthError.generationChanged)) } }
        }
        issuanceCooldown.clear()
        originCooldown.clear()
        businessCooldowns.clear()
        rejectedCredentials = NovaAuthRejectedCredentials()
        dependencies.http.clearReadCache()
        do {
            try persist(replacement)
            try retryStorageWork()
        } catch {
            storageFailed = true
            throw NovaAuthError.storageUnavailable
        }
        NovaAuthDiagnostics.log(.contextReplaced, logger: dependencies.logger)
        return replacement.context
    }
}

final class NovaAuthIssuanceFlight {
    let context: NovaAuthContext
    let intent: NovaAuthRequestIntent
    var waiters: [UUID: (Result<NovaAuthTokenRecord, Error>) -> Void] = [:]
    var cancelChild: (() -> Void)?
    var irreversible = false
    var issuanceStart: NovaAuthTime?
    var pendingProbeReserved = false
    var diagnosticPhase: NovaAuthDiagnostics.Phase = .registrationChallenge
    let sponsored: Bool

    init(context: NovaAuthContext, sponsored: Bool, intent: NovaAuthRequestIntent) {
        self.context = context
        self.sponsored = sponsored
        self.intent = intent
    }
}
