import Foundation
import Keystore_iOS
import SDKLogger
import NovaAppAttest

public struct AnalyticsConfiguration {
    public let attestationProvider: AnalyticsAttestationProviding

    public let appAttestService: AppAttestServiceProtocol

    public let appVersion: String

    public let storeDirectory: URL

    public let isFirstLaunch: () -> Bool

    public let settingsManager: SettingsManagerProtocol
    public let logger: SDKLoggerProtocol

    public let operationQueue: OperationQueue

    public let analyticsOperationQueue: OperationQueue

    public init(
        attestationProvider: AnalyticsAttestationProviding,
        appAttestService: AppAttestServiceProtocol,
        appVersion: String,
        storeDirectory: URL,
        isFirstLaunch: @escaping () -> Bool,
        settingsManager: SettingsManagerProtocol,
        logger: SDKLoggerProtocol,
        operationQueue: OperationQueue,
        analyticsOperationQueue: OperationQueue
    ) {
        self.attestationProvider = attestationProvider
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
