import Foundation
import Keystore_iOS

final class AnalyticsIdentity {
    private let settingsManager: SettingsManagerProtocol
    private let mutex = NSLock()

    /// One per instance, therefore one per process. An iOS process can span days;
    /// the id is still per process (parity with Android).
    let sessionId: String = UUID().uuidString.lowercased()

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

// MARK: - AnalyticsIdentityProtocol

extension AnalyticsIdentity: AnalyticsIdentityProtocol {
    /// Created on first call — which happens inside the flush path, behind the consent
    /// guard — and never before.
    func installId() -> String {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let existing = settingsManager.analyticsInstallId {
            return existing
        }

        let created = UUID().uuidString.lowercased()
        settingsManager.analyticsInstallId = created

        return created
    }

    /// A delete, never a rotation: an opted-out install has no id at all.
    func forgetInstallId() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        settingsManager.analyticsInstallId = nil
    }
}
