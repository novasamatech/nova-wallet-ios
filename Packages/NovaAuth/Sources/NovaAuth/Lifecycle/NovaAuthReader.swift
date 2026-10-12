import Foundation
import Operation_iOS

public final class NovaAuthReader: NovaAuthClientProtocol {
    private let dependencies: NovaAuthReaderDependencies
    private let gate = NSLock()
    private var originCooldown = NovaAuthCooldown()
    private var businessCooldowns = NovaAuthBusinessCooldowns()
    private var rejectedCredentials = NovaAuthRejectedCredentials()

    public convenience init(configuration: NovaAuthReaderConfiguration) {
        self.init(dependencies: NovaAuthReaderDependencies(
            origin: configuration.origin,
            tokenStore: NovaAuthKeychainTokenStore(configuration: configuration.sharedStore),
            clock: NovaAuthContinuousClock(),
            http: NovaAuthHTTPTransport(),
            requestQueue: configuration.requestQueue
        ))
    }

    init(dependencies: NovaAuthReaderDependencies) { self.dependencies = dependencies }

    public var isSupported: Bool { true }

    public func createContextWrapper() -> CompoundOperationWrapper<NovaAuthContext> {
        let operation = ClosureOperation<NovaAuthContext> { [self] in
            try gate.novaAuthLocked { try currentRecord(context: nil).context }
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    public func createAdmissionWrapper(
        in context: NovaAuthContext,
        intent: NovaAuthRequestIntent
    ) -> CompoundOperationWrapper<Void> {
        let operation = NovaAuthWaiterOperation<Void> { [self] cancellation, completion in
            demand(context: context, intent: intent, cancellation: cancellation) { completion($0.map { _ in () }) }
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    public func createResponseWrapper(
        for request: NovaAuthRequest,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        NovaAuthAuthorizedOperationFactory(owner: self).createWrapper(request: request, beforeSend: beforeSend)
    }

    private func currentRecord(context: NovaAuthContext?) throws -> NovaAuthTokenRecord {
        let record: NovaAuthTokenRecord
        do {
            guard let current = try dependencies.tokenStore.load() else { throw NovaAuthError.credentialUnavailable }
            record = current
        } catch let error as NovaAuthError {
            throw error
        } catch { throw NovaAuthError.storageUnavailable }
        guard record.context.origin == dependencies.origin else { throw NovaAuthError.generationChanged }
        if let context, record.context != context { throw NovaAuthError.generationChanged }
        let now = try dependencies.clock.now()
        try originCooldown.check(now: now)
        try rejectedCredentials.check(record, now: now)
        do {
            _ = try NovaAuthTokenValidation.remaining(record, context: record.context, clientID: nil, now: now)
            return record
        } catch {
            do {
                try dependencies.tokenStore.remove(ifMatching: record)
            } catch { throw NovaAuthError.storageUnavailable }
            throw NovaAuthError.credentialUnavailable
        }
    }
}

extension NovaAuthReader: NovaAuthCredentialAuthority {
    var http: NovaAuthHTTPProtocol { dependencies.http }
    var requestQueue: OperationQueue { dependencies.requestQueue }

    func demand(
        context: NovaAuthContext,
        intent _: NovaAuthRequestIntent,
        cancellation: NovaAuthCancellation,
        completion: @escaping (Result<NovaAuthTokenRecord, Error>) -> Void
    ) {
        let result: Result<NovaAuthTokenRecord, Error> = gate.novaAuthLocked {
            do {
                try cancellation.check()
                return .success(try currentRecord(context: context))
            } catch { return .failure(NovaAuth.safeError(error)) }
        }
        if !cancellation.isCancelled { completion(result) }
    }

    func checkSend(request: NovaAuthRequest, record: NovaAuthTokenRecord) throws {
        try gate.novaAuthLocked {
            _ = try currentRecord(context: request.context)
            let now = try dependencies.clock.now()
            try businessCooldowns.check(request: request, now: now)
            _ = try NovaAuthTokenValidation.remaining(record, context: request.context, clientID: nil, now: now)
            try rejectedCredentials.check(record, now: now)
        }
    }

    func receive(_ result: Result<NovaAuthResponse, Error>, request: NovaAuthRequest) throws {
        try gate.novaAuthLocked {
            // Do not require the sent record to remain current: another process may already replace it.
            guard let current = try dependencies.tokenStore.load(), current.context == request.context else {
                throw NovaAuthError.generationChanged
            }
            let now = try dependencies.clock.now()
            businessCooldowns.receive(result, request: request, now: now, random: 0.5, origin: &originCooldown)
        }
    }

    func reject(record: NovaAuthTokenRecord, repeated: Bool, requestID _: String?) throws {
        try gate.novaAuthLocked {
            rejectedCredentials.reject(record)
            if repeated { originCooldown.fail(now: try dependencies.clock.now(), random: 0.5) }
            do {
                try dependencies.tokenStore.remove(ifMatching: record)
            } catch { throw NovaAuthError.storageUnavailable }
        }
    }

    func recovered(requestID _: String?) {}
}
