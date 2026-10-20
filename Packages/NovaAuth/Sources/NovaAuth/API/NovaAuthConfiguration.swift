import Foundation
import Keystore_iOS
import SDKLogger

public struct NovaAuthConfiguration {
    public let appIdentity: NovaAuthAppIdentity
    public let keychainService: String
    public let settingsManager: SettingsManagerProtocol
    public let ownerQueue: OperationQueue
    public let bootstrapQueue: OperationQueue
    public let requestQueue: OperationQueue
    public let logger: SDKLoggerProtocol?

    public init(
        appIdentity: NovaAuthAppIdentity,
        keychainService: String,
        settingsManager: SettingsManagerProtocol,
        ownerQueue: OperationQueue,
        bootstrapQueue: OperationQueue,
        requestQueue: OperationQueue,
        logger: SDKLoggerProtocol?
    ) {
        self.appIdentity = appIdentity
        self.keychainService = keychainService
        self.settingsManager = settingsManager
        self.ownerQueue = ownerQueue
        self.bootstrapQueue = bootstrapQueue
        self.requestQueue = requestQueue
        self.logger = logger
    }
}
