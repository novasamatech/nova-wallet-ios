import Foundation
import Keystore_iOS
import SDKLogger
import NovaAppAttest

/// Everything the analytics stack needs from its host — the whole package boundary.
public struct AnalyticsConfiguration {
    public let gatewayURL: URL

    /// The full App ID and App Attest environment the gateway binds this installation's key to.
    public let appIdentity: AppAttestAppIdentity

    /// Injected rather than built in place: whether this device can attest decides whether analytics
    /// runs at all, so a test must be able to answer it without a Secure Enclave.
    public let appAttestService: AppAttestServiceProtocol

    public let appVersion: String

    public let storeDirectory: URL

    public let isFirstLaunch: () -> Bool

    public let settingsManager: SettingsManagerProtocol
    public let remoteSettings: AnalyticsRemoteSettings
    public let logger: SDKLoggerProtocol

    public let operationQueue: OperationQueue

    public let analyticsOperationQueue: OperationQueue

    public init(
        gatewayURL: URL,
        appIdentity: AppAttestAppIdentity,
        appAttestService: AppAttestServiceProtocol,
        appVersion: String,
        storeDirectory: URL,
        isFirstLaunch: @escaping () -> Bool,
        settingsManager: SettingsManagerProtocol,
        remoteSettings: AnalyticsRemoteSettings,
        logger: SDKLoggerProtocol,
        operationQueue: OperationQueue,
        analyticsOperationQueue: OperationQueue
    ) {
        self.gatewayURL = gatewayURL
        self.appIdentity = appIdentity
        self.appAttestService = appAttestService
        self.appVersion = appVersion
        self.storeDirectory = storeDirectory
        self.isFirstLaunch = isFirstLaunch
        self.settingsManager = settingsManager
        self.remoteSettings = remoteSettings
        self.logger = logger
        self.operationQueue = operationQueue
        self.analyticsOperationQueue = analyticsOperationQueue
    }
}
