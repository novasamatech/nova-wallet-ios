import Foundation
import Keystore_iOS
import SDKLogger

/// Everything the analytics stack needs from its host. No singletons, no `Bundle.main`
/// lookups, no app types — this struct is the whole boundary.
public struct AnalyticsConfiguration {
    public let gatewayURL: URL

    /// `CFBundleShortVersionString` only; the gateway does not expect a build number.
    /// Supplied by the host because `Bundle(for:)` inside a package resolves to the
    /// package bundle, not the app.
    public let appVersion: String

    /// Directory for `AnalyticsDataModel.sqlite`. The app passes its app-group CoreData
    /// directory so the file sits beside the user store.
    public let storeDirectory: URL

    /// Drives the attestation mode ladder.
    public let isReleaseBuild: Bool

    /// Read at `setup()` for the `app_opened` event. A closure rather than a `Bool` because
    /// the host flips it during launch.
    public let isFirstLaunch: () -> Bool

    public let settingsManager: SettingsManagerProtocol
    public let remoteSettings: AnalyticsRemoteSettings
    public let logger: SDKLoggerProtocol

    /// Shared, concurrent. The attestation chain nests wrappers, which a serial queue
    /// cannot run.
    public let operationQueue: OperationQueue

    /// Serial. Persistence runs here while a slow POST is in flight on `operationQueue`.
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
