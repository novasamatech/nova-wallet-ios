import Foundation
import Keystore_iOS

public final class AnalyticsIdentity {
    private let settingsManager: SettingsManagerProtocol
    private let mutex = NSLock()

    private var isCreationBlocked: Bool = false

    private var currentConsentEpoch: Int

    public var consentEpoch: Int {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return currentConsentEpoch
    }

    private var currentSessionId: String = UUID().uuidString.lowercased()

    public var sessionId: String {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return currentSessionId
    }

    public init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager

        currentConsentEpoch = settingsManager.analyticsConsentEpoch
    }
}

// MARK: - Private

private extension AnalyticsIdentity {
    func advanceConsentEpochLocked() {
        currentConsentEpoch += 1
        settingsManager.analyticsConsentEpoch = currentConsentEpoch
    }
}

// MARK: - AnalyticsIdentityProtocol

extension AnalyticsIdentity: AnalyticsIdentityProtocol {
    public func installId() -> String? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let existing = settingsManager.analyticsInstallId {
            return existing
        }

        guard !isCreationBlocked else {
            return nil
        }

        let created = UUID().uuidString.lowercased()
        settingsManager.analyticsInstallId = created

        return created
    }

    public func forgetInstallId() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        settingsManager.analyticsInstallId = nil
        isCreationBlocked = true
        advanceConsentEpochLocked()
    }

    public func allowCreation() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isCreationBlocked = false
        currentSessionId = UUID().uuidString.lowercased()
        advanceConsentEpochLocked()
    }
}
