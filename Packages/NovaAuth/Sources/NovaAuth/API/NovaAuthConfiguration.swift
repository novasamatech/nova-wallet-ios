import Foundation
import Keystore_iOS
import SDKLogger

public struct NovaAuthSharedStoreConfiguration {
    public let accessGroup: String
    public let containerURL: URL
    /// Stable host-app bundle identifier, shared by that app and its extensions.
    public let hostAppNamespace: String

    public init(accessGroup: String, containerURL: URL, hostAppNamespace: String) throws {
        let parts = hostAppNamespace.split(separator: ".", omittingEmptySubsequences: false)
        guard (3 ... 255).contains(hostAppNamespace.utf8.count), parts.count >= 2,
              parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy {
                  (65 ... 90).contains($0) || (97 ... 122).contains($0) || (48 ... 57).contains($0) || $0 == 45
              } }) else { throw NovaAuthError.invalidConfiguration }
        self.accessGroup = accessGroup
        self.containerURL = containerURL
        self.hostAppNamespace = hostAppNamespace
    }
}

public struct NovaAuthConfiguration {
    public let appIdentity: NovaAuthAppIdentity
    public let settingsManager: SettingsManagerProtocol
    public let sharedStore: NovaAuthSharedStoreConfiguration
    public let ownerQueue: OperationQueue
    public let bootstrapQueue: OperationQueue
    public let requestQueue: OperationQueue
    public let logger: SDKLoggerProtocol?

    public init(
        appIdentity: NovaAuthAppIdentity,
        settingsManager: SettingsManagerProtocol,
        sharedStore: NovaAuthSharedStoreConfiguration,
        ownerQueue: OperationQueue,
        bootstrapQueue: OperationQueue,
        requestQueue: OperationQueue,
        logger: SDKLoggerProtocol?
    ) {
        self.appIdentity = appIdentity
        self.settingsManager = settingsManager
        self.sharedStore = sharedStore
        self.ownerQueue = ownerQueue
        self.bootstrapQueue = bootstrapQueue
        self.requestQueue = requestQueue
        self.logger = logger
    }
}

public struct NovaAuthReaderConfiguration {
    public let origin: NovaAuthOrigin
    public let sharedStore: NovaAuthSharedStoreConfiguration
    public let requestQueue: OperationQueue
    public init(origin: NovaAuthOrigin, sharedStore: NovaAuthSharedStoreConfiguration, requestQueue: OperationQueue) {
        self.origin = origin
        self.sharedStore = sharedStore
        self.requestQueue = requestQueue
    }
}
