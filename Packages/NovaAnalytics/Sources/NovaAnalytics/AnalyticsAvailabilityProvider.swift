import Foundation
import NovaAppAttest

/// The single "off" besides consent: an unattestable device and a remote-disabled
/// build are indistinguishable at the guard.
public final class AnalyticsAvailabilityProvider {
    private let mutex = NSLock()
    private let attestationMode: BackendAttestationMode
    private var remoteEnabled: Bool

    public init(attestationMode: BackendAttestationMode, remoteEnabled: Bool = true) {
        self.attestationMode = attestationMode
        self.remoteEnabled = remoteEnabled
    }

    public func setRemoteEnabled(_ enabled: Bool) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        remoteEnabled = enabled
    }
}

// MARK: - AnalyticsAvailabilityProviderProtocol

extension AnalyticsAvailabilityProvider: AnalyticsAvailabilityProviderProtocol {
    public var isAvailable: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return attestationMode != .unavailable && remoteEnabled
    }
}
