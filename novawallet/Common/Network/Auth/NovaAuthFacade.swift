import Foundation
import Keystore_iOS
import NovaAuth
import Operation_iOS

struct NovaAuthEndpoint {
    let context: NovaAuthContext
    let client: NovaAuthClientProtocol
    // Captured with the accepted context, before observer delivery.
    let invalidationRevision: UInt64
}

struct NovaAuthEndpointAvailability {
    let revision: UInt64
    let invalidationRevision: UInt64
    let endpoint: NovaAuthEndpoint?

    init(revision: UInt64 = 0, invalidationRevision: UInt64 = 0, endpoint: NovaAuthEndpoint? = nil) {
        self.revision = revision
        self.invalidationRevision = invalidationRevision
        self.endpoint = endpoint
    }
}

protocol NovaAuthProvidingProtocol: AnyObject {
    var endpointAvailability: NovaAuthEndpointAvailability { get }
    func createEndpointWrapper() -> CompoundOperationWrapper<NovaAuthEndpoint>
    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void)
    func addAvailabilityObserver(
        _ owner: AnyObject,
        closure: @escaping (NovaAuthEndpointAvailability) -> Void
    ) -> NovaAuthEndpointAvailability
}

extension NovaAuthProvidingProtocol {
    var endpointAvailability: NovaAuthEndpointAvailability { NovaAuthEndpointAvailability() }
    func addAvailabilityObserver(
        _: AnyObject,
        closure _: @escaping (NovaAuthEndpointAvailability) -> Void
    ) -> NovaAuthEndpointAvailability { endpointAvailability }
    func addContextObserver(_: AnyObject, closure _: @escaping () -> Void) {}
}

final class NovaAuthFacade: NovaAuthProvidingProtocol {
    private struct Observer {
        weak var owner: AnyObject?
        let closure: () -> Void
    }

    private struct AvailabilityObserver {
        weak var owner: AnyObject?
        let closure: (NovaAuthEndpointAvailability) -> Void
    }

    private let configProvider: GlobalConfigProviding
    private let client: NovaAuthClientProtocol?
    private let activate: (NovaAuthOrigin) throws -> NovaAuthContext
    private let resetAuth: () throws -> Void
    private let contextInvalidationID: () -> UUID?
    private let isUnitTesting: Bool
    private let mutex = NSRecursiveLock()
    private let availabilityLock = NSLock()
    private var publishedAvailability = NovaAuthEndpointAvailability()
    private var latestSnapshot: GlobalConfigSnapshot?
    private var observers: [Observer] = []
    private var availabilityObservers: [AvailabilityObserver] = []

    init(
        configProvider: GlobalConfigProviding,
        client: NovaAuthClientProtocol?,
        isUnitTesting: Bool = false,
        contextInvalidationID: @escaping () -> UUID? = { nil },
        activate: @escaping (NovaAuthOrigin) throws -> NovaAuthContext,
        reset: @escaping () throws -> Void
    ) {
        self.configProvider = configProvider
        self.client = client
        self.isUnitTesting = isUnitTesting
        self.contextInvalidationID = contextInvalidationID
        self.activate = activate
        resetAuth = reset
        configProvider.addSnapshotObserver(self) { [weak self] snapshot in
            _ = try? self?.adopt(snapshot)
        }
    }

    var isSupported: Bool { !isUnitTesting && client?.isSupported == true }

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

    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void) {
        mutex.lock()
        observers = observers.filter { $0.owner != nil && $0.owner !== owner }
        observers.append(Observer(owner: owner, closure: closure))
        mutex.unlock()
    }

    func addAvailabilityObserver(
        _ owner: AnyObject,
        closure: @escaping (NovaAuthEndpointAvailability) -> Void
    ) -> NovaAuthEndpointAvailability {
        mutex.lock()
        defer { mutex.unlock() }
        availabilityObservers = availabilityObservers.filter { $0.owner != nil && $0.owner !== owner }
        availabilityObservers.append(AvailabilityObserver(owner: owner, closure: closure))
        return availability
    }

    func reset() throws {
        mutex.lock()
        let result = Result { try resetAuth() }
        publishLocked(nil, invalidated: true)
        let callbacks = callbacksLocked(invalidated: true)
        mutex.unlock()
        callbacks.forEach { $0() }
        try result.get()
    }

    private func adopt(_ snapshot: GlobalConfigSnapshot) throws -> NovaAuthEndpoint {
        mutex.lock()
        let previous = availability
        let result = Result { try adoptLocked(snapshot) }
        let callbacks = previous.revision != availability.revision
            ? callbacksLocked(invalidated: previous.invalidationRevision != availability.invalidationRevision) : []
        mutex.unlock()
        callbacks.forEach { $0() }
        return try result.get()
    }

    private func adoptLocked(_ snapshot: GlobalConfigSnapshot) throws -> NovaAuthEndpoint {
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
                publishLocked(nil, invalidated: true)
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
        publishLocked(accepted, invalidated: changed)
        return accepted
    }
}

// MARK: Private

private extension NovaAuthFacade {
    // Main-thread cache peeks read this, so it must never wait on the adoption mutex held across auth I/O.
    var availability: NovaAuthEndpointAvailability {
        get {
            availabilityLock.lock()
            defer { availabilityLock.unlock() }
            return publishedAvailability
        }
        set {
            availabilityLock.lock()
            publishedAvailability = newValue
            availabilityLock.unlock()
        }
    }

    func publishLocked(_ endpoint: NovaAuthEndpoint?, invalidated: Bool) {
        availability = NovaAuthEndpointAvailability(
            revision: availability.revision + 1,
            invalidationRevision: availability.invalidationRevision + (invalidated ? 1 : 0),
            endpoint: endpoint
        )
    }

    func callbacksLocked(invalidated: Bool) -> [() -> Void] {
        observers = observers.filter { $0.owner != nil }
        availabilityObservers = availabilityObservers.filter { $0.owner != nil }
        let current = availability
        let invalidations = invalidated ? observers.map(\.closure) : []
        let readiness = availabilityObservers.map { observer in { observer.closure(current) } }
        return invalidations + readiness
    }

    func createOrigin(from baseURL: URL) throws -> NovaAuthOrigin {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/" else {
            throw NovaAuthError.invalidConfiguration
        }

        // Config base URLs may end at the root, but signed and stored origins must remain strict.
        let value = components.percentEncodedPath == "/"
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        return try NovaAuthOrigin(value)
    }
}

extension NovaAuthFacade {
    static let shared: NovaAuthFacade = {
        let client: NovaAuth?
        if !ProcessInfo.processInfo.arguments.contains("-UNITTEST"),
           let appIdentity = ApplicationConfig.shared.novaAuthAppIdentity,
           let sharedStore = SharedContainerGroup.novaAuthStore {
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
            },
            reset: { try client?.reset() }
        )
    }()
}
