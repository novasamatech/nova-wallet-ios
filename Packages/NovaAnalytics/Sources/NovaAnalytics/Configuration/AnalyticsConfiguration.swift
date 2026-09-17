import Foundation
import Keystore_iOS
import SDKLogger
import NovaAppAttest

public struct AnalyticsConfiguration {
    public let infraURLProvider: AnalyticsInfraURLProviding

    public let appIdentity: AppAttestAppIdentity

    public let appAttestService: AppAttestServiceProtocol

    public let appVersion: String

    public let storeDirectory: URL

    public let isFirstLaunch: () -> Bool

    public let settingsManager: SettingsManagerProtocol
    public let logger: SDKLoggerProtocol

    public let operationQueue: OperationQueue

    public let analyticsOperationQueue: OperationQueue

    public init(
        infraURLProvider: AnalyticsInfraURLProviding,
        appIdentity: AppAttestAppIdentity,
        appAttestService: AppAttestServiceProtocol,
        appVersion: String,
        storeDirectory: URL,
        isFirstLaunch: @escaping () -> Bool,
        settingsManager: SettingsManagerProtocol,
        logger: SDKLoggerProtocol,
        operationQueue: OperationQueue,
        analyticsOperationQueue: OperationQueue
    ) {
        self.infraURLProvider = infraURLProvider
        self.appIdentity = appIdentity
        self.appAttestService = appAttestService
        self.appVersion = appVersion
        self.storeDirectory = storeDirectory
        self.isFirstLaunch = isFirstLaunch
        self.settingsManager = settingsManager
        self.logger = logger
        self.operationQueue = operationQueue
        self.analyticsOperationQueue = analyticsOperationQueue
    }
}
