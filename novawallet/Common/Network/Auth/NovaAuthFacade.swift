import Foundation
import Keystore_iOS
import NovaAuth
import Operation_iOS

struct NovaAuthEndpoint {
    let context: NovaAuthContext
    let client: NovaAuthClientProtocol
    let invalidationRevision: UInt64
}

struct NovaAuthEndpointAvailability {
    let invalidationRevision: UInt64
    let endpoint: NovaAuthEndpoint?

    init(invalidationRevision: UInt64 = 0, endpoint: NovaAuthEndpoint? = nil) {
        self.invalidationRevision = invalidationRevision
        self.endpoint = endpoint
    }
}

protocol NovaAuthProvidingProtocol: AnyObject {
    var endpointAvailability: NovaAuthEndpointAvailability { get }
    func createEndpointWrapper() -> CompoundOperationWrapper<NovaAuthEndpoint>
    func addAvailabilityObserver(
        _ owner: AnyObject,
        closure: @escaping (NovaAuthEndpointAvailability) -> Void
    ) -> NovaAuthEndpointAvailability
}

final class NovaAuthFacade: NovaAuthProvidingProtocol {
    private struct AvailabilityObserver {
        weak var owner: AnyObject?
        let closure: (NovaAuthEndpointAvailability) -> Void
    }

    private let configProvider: GlobalConfigProviding
    private let client: NovaAuthClientProtocol?
    private let activate: (NovaAuthOrigin) throws -> NovaAuthContext
    private let contextInvalidationID: () -> UUID?
    private let logger: LoggerProtocol
    private let mutex = NSLock()
    private var latestSnapshot: GlobalConfigSnapshot?
    private let availabilityLock = NSLock()
    private var publishedAvailability = NovaAuthEndpointAvailability()
    private var availabilityObservers: [AvailabilityObserver] = []

    init(
        configProvider: GlobalConfigProviding,
        client: NovaAuthClientProtocol?,
        contextInvalidationID: @escaping () -> UUID?,
        activate: @escaping (NovaAuthOrigin) throws -> NovaAuthContext,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.configProvider = configProvider
        self.client = client
        self.contextInvalidationID = contextInvalidationID
        self.activate = activate
        self.logger = logger
        configProvider.addSnapshotObserver(self) { [weak self] snapshot in
            guard let self else { return }
            do {
                _ = try adopt(snapshot)
            } catch {
                logger.warning("NovaAuth config refresh not adopted: \(error)")
            }
        }
    }

    var isSupported: Bool { client?.isSupported == true }

    var endpointAvailability: NovaAuthEndpointAvailability { availability }

    func createEndpointWrapper() -> CompoundOperationWrapper<NovaAuthEndpoint> {
        guard isSupported else { return .createWithError(NovaAuthError.unsupported) }
        let config = configProvider.createConfigSnapshotWrapper()
        let map = ClosureOperation<NovaAuthEndpoint> { [self] in
            try adopt(config.targetOperation.extractNoCancellableResultData())
        }
        map.addDependency(config.targetOperation)
        return config.insertingTail(operation: map)
    }

    func addAvailabilityObserver(
        _ owner: AnyObject,
        closure: @escaping (NovaAuthEndpointAvailability) -> Void
    ) -> NovaAuthEndpointAvailability {
        availabilityLock.lock()
        defer { availabilityLock.unlock() }
        availabilityObservers = availabilityObservers.filter { $0.owner != nil && $0.owner !== owner }
        availabilityObservers.append(AvailabilityObserver(owner: owner, closure: closure))
        return publishedAvailability
    }

    private func adopt(_ snapshot: GlobalConfigSnapshot) throws -> NovaAuthEndpoint {
        var callbacks: [() -> Void] = []
        mutex.lock()
        let result = Result { try adoptLocked(snapshot, callbacks: &callbacks) }
        mutex.unlock()
        callbacks.forEach { $0() }
        return try result.get()
    }

    private func adoptLocked(
        _ snapshot: GlobalConfigSnapshot,
        callbacks: inout [() -> Void]
    ) throws -> NovaAuthEndpoint {
        guard isSupported, let client else { throw NovaAuthError.unsupported }
        let acceptedSnapshot: GlobalConfigSnapshot
        if let latestSnapshot, snapshot.revision < latestSnapshot.revision {
            acceptedSnapshot = latestSnapshot
        } else { acceptedSnapshot = snapshot }
        let origin = try createOrigin(from: acceptedSnapshot.config.infraUrl)
        latestSnapshot = acceptedSnapshot
        let previousInvalidationID = contextInvalidationID()
        let context: NovaAuthContext
        do {
            context = try activate(origin)
        } catch {
            if previousInvalidationID != contextInvalidationID() {
                callbacks = publishLocked(nil, invalidated: true)
            }
            throw error
        }
        let changed = previousInvalidationID != contextInvalidationID()
            || (availability.endpoint != nil && availability.endpoint?.context != context)
        let accepted = NovaAuthEndpoint(
            context: context,
            client: client,
            invalidationRevision: availability.invalidationRevision + (changed ? 1 : 0)
        )
        callbacks = publishLocked(accepted, invalidated: changed)
        return accepted
    }
}

// MARK: Private

private extension NovaAuthFacade {
    var availability: NovaAuthEndpointAvailability {
        availabilityLock.lock()
        defer { availabilityLock.unlock() }
        return publishedAvailability
    }

    func publishLocked(_ endpoint: NovaAuthEndpoint?, invalidated: Bool) -> [() -> Void] {
        availabilityLock.lock()
        defer { availabilityLock.unlock() }
        let current = NovaAuthEndpointAvailability(
            invalidationRevision: publishedAvailability.invalidationRevision + (invalidated ? 1 : 0),
            endpoint: endpoint
        )
        publishedAvailability = current
        availabilityObservers = availabilityObservers.filter { $0.owner != nil }
        return availabilityObservers.map { observer in { observer.closure(current) } }
    }

    func createOrigin(from baseURL: URL) throws -> NovaAuthOrigin {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/" else {
            throw NovaAuthError.invalidConfiguration
        }

        let value = components.percentEncodedPath == "/"
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        return try NovaAuthOrigin(value)
    }
}

extension NovaAuthFacade {
    static let shared: NovaAuthFacade = {
        let client: NovaAuth?
        if !AppDelegate.isUnitTesting,
           let appIdentity = ApplicationConfig.shared.novaAuthAppIdentity,
           let sharedStore = ApplicationConfig.shared.novaAuthSharedStore {
            client = NovaAuth(configuration: NovaAuthConfiguration(
                appIdentity: appIdentity,
                settingsManager: SettingsManager.shared,
                sharedStore: sharedStore,
                ownerQueue: OperationManagerFacade.novaAuthOwnerQueue,
                bootstrapQueue: OperationManagerFacade.novaAuthBootstrapQueue,
                requestQueue: OperationManagerFacade.novaAuthRequestQueue,
                logger: Logger.shared
            ))
        } else { client = nil }
        return NovaAuthFacade(
            configProvider: GlobalConfigProvider.shared,
            client: client,
            contextInvalidationID: { client?.contextInvalidationID },
            activate: { origin in
                guard let client else { throw NovaAuthError.unsupported }
                return try client.activate(origin: origin)
            }
        )
    }()
}
