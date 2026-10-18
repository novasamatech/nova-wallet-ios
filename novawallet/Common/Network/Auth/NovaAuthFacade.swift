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
}

final class NovaAuthFacade: NovaAuthProvidingProtocol {
    private let configProvider: GlobalConfigProviding
    private let client: NovaAuthClientProtocol?
    private let activate: (NovaAuthOrigin) throws -> NovaAuthContext
    private let adoptionLock = NSLock()

    @Atomic(defaultValue: nil)
    private var endpoint: NovaAuthEndpoint?

    init(
        configProvider: GlobalConfigProviding,
        client: NovaAuthClientProtocol?,
        activate: @escaping (NovaAuthOrigin) throws -> NovaAuthContext
    ) {
        self.configProvider = configProvider
        self.client = client
        self.activate = activate
    }

    var isSupported: Bool { client?.isSupported == true }

    func createEndpointWrapper() -> CompoundOperationWrapper<NovaAuthEndpoint> {
        guard isSupported, let client else { return .createWithError(NovaAuthError.unsupported) }
        if let endpoint { return .createWithResult(endpoint) }
        let config = configProvider.createConfigWrapper()
        let map = ClosureOperation<NovaAuthEndpoint> { [self] in
            try adopt(config.targetOperation.extractNoCancellableResultData(), client: client)
        }
        map.addDependency(config.targetOperation)
        return config.insertingTail(operation: map)
    }
}

// MARK: Private

private extension NovaAuthFacade {
    func adopt(_ config: GlobalConfig, client: NovaAuthClientProtocol) throws -> NovaAuthEndpoint {
        adoptionLock.lock()
        defer { adoptionLock.unlock() }
        if let endpoint { return endpoint }
        let context = try activate(createOrigin(from: config.infraUrl))
        let accepted = NovaAuthEndpoint(context: context, client: client)
        endpoint = accepted
        return accepted
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
        if !EnviromentVariables.isUnitTesting,
           let appIdentity = ApplicationConfig.shared.novaAuthAppIdentity {
            client = NovaAuth(configuration: NovaAuthConfiguration(
                appIdentity: appIdentity,
                settingsManager: SettingsManager.shared,
                ownerQueue: OperationManagerFacade.novaAuthOwnerQueue,
                bootstrapQueue: OperationManagerFacade.novaAuthBootstrapQueue,
                requestQueue: OperationManagerFacade.novaAuthRequestQueue,
                logger: Logger.shared
            ))
        } else { client = nil }
        return NovaAuthFacade(
            configProvider: GlobalConfigProvider.shared,
            client: client,
            activate: { origin in
                guard let client else { throw NovaAuthError.unsupported }
                return try client.activate(origin: origin)
            }
        )
    }()
}
