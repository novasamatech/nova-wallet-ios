import Foundation
import Keystore_iOS
import NovaAuth
import Operation_iOS

struct NovaAuthEndpoint {
    let context: NovaAuthContext
    let client: NovaAuthClientProtocol
}

protocol NovaAuthProvidingProtocol: AnyObject {
    func createEndpointWrapper() -> CompoundOperationWrapper<NovaAuthEndpoint>
    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void)
}

extension NovaAuthProvidingProtocol {
    func addContextObserver(_: AnyObject, closure _: @escaping () -> Void) {}
}

final class NovaAuthFacade: NovaAuthProvidingProtocol {
    private struct Observer {
        weak var owner: AnyObject?
        let closure: () -> Void
    }

    private let configProvider: GlobalConfigProviding
    private let client: NovaAuthClientProtocol?
    private let activate: (NovaAuthOrigin) throws -> NovaAuthContext
    private let resetAuth: () throws -> Void
    private let contextInvalidationID: () -> UUID?
    private let isUnitTesting: Bool
    private let mutex = NSRecursiveLock()
    private var endpoint: NovaAuthEndpoint?
    private var latestSnapshot: GlobalConfigSnapshot?
    private var observers: [Observer] = []

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

    func reset() throws {
        mutex.lock()
        defer {
            endpoint = nil
            notifyContextInvalidation()
            mutex.unlock()
        }
        try resetAuth()
    }

    private func adopt(_ snapshot: GlobalConfigSnapshot) throws -> NovaAuthEndpoint {
        mutex.lock()
        defer { mutex.unlock() }
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
                endpoint = nil
                notifyContextInvalidation()
            }
            throw error
        }
        let changed = previousInvalidationID != contextInvalidationID()
            || (endpoint != nil && endpoint?.context != context)
        let accepted = NovaAuthEndpoint(context: context, client: client)
        endpoint = accepted
        if changed { notifyContextInvalidation() }
        return accepted
    }
}

// MARK: Private

private extension NovaAuthFacade {
    func notifyContextInvalidation() {
        observers = observers.filter { $0.owner != nil }
        observers.forEach { $0.closure() }
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
