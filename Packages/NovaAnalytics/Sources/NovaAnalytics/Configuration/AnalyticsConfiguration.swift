import Foundation
import Keystore_iOS
import SDKLogger

public struct AnalyticsConfiguration {
    public let authProvider: AnalyticsAuthProvidingProtocol

    public let appVersion: String

    public let storeDirectory: URL

    public let isFirstLaunch: () -> Bool

    public let assetListStyle: () -> AnalyticsAssetListStyle

    public let settingsManager: SettingsManagerProtocol
    public let logger: SDKLoggerProtocol

    public let operationQueue: OperationQueue

    public let analyticsOperationQueue: OperationQueue

    public init(
        authProvider: AnalyticsAuthProvidingProtocol,
        appVersion: String,
        storeDirectory: URL,
        isFirstLaunch: @escaping () -> Bool,
        assetListStyle: @escaping () -> AnalyticsAssetListStyle,
        settingsManager: SettingsManagerProtocol,
        logger: SDKLoggerProtocol,
        operationQueue: OperationQueue,
        analyticsOperationQueue: OperationQueue
    ) {
        self.authProvider = authProvider
        self.appVersion = appVersion
        self.storeDirectory = storeDirectory
        self.isFirstLaunch = isFirstLaunch
        self.assetListStyle = assetListStyle
        self.settingsManager = settingsManager
        self.logger = logger
        self.operationQueue = operationQueue
        self.analyticsOperationQueue = analyticsOperationQueue
    }
}
