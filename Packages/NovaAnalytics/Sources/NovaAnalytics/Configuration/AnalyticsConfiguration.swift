import Foundation
import Keystore_iOS
import SDKLogger

/// Everything the analytics stack needs from its host — the whole package boundary.
public struct AnalyticsConfiguration {
    public let gatewayURL: URL

    public let appVersion: String

    public let storeDirectory: URL

    public let isReleaseBuild: Bool

    public let isFirstLaunch: () -> Bool

    public let settingsManager: SettingsManagerProtocol
    public let remoteSettings: AnalyticsRemoteSettings
    public let logger: SDKLoggerProtocol

    public let operationQueue: OperationQueue

    public let analyticsOperationQueue: OperationQueue

    public init(
        gatewayURL: URL,
        appVersion: String,
        storeDirectory: URL,
        isReleaseBuild: Bool,
        isFirstLaunch: @escaping () -> Bool,
        settingsManager: SettingsManagerProtocol,
        remoteSettings: AnalyticsRemoteSettings,
        logger: SDKLoggerProtocol,
        operationQueue: OperationQueue,
        analyticsOperationQueue: OperationQueue
    ) {
        self.gatewayURL = gatewayURL
        self.appVersion = appVersion
        self.storeDirectory = storeDirectory
        self.isReleaseBuild = isReleaseBuild
        self.isFirstLaunch = isFirstLaunch
        self.settingsManager = settingsManager
        self.remoteSettings = remoteSettings
        self.logger = logger
        self.operationQueue = operationQueue
        self.analyticsOperationQueue = analyticsOperationQueue
    }
}
