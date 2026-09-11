import Foundation
import Keystore_iOS
import Operation_iOS
import NovaAppAttest

/// Unresolved reads as unavailable, so nothing is prompted, recorded or uploaded before the
/// remote switch has been read at least once on this install.
public final class AnalyticsAvailabilityProvider {
    private struct ObserverWrapper {
        weak var owner: AnyObject?
        let closure: (Bool) -> Void
        let queue: DispatchQueue?
    }

    private let mutex = NSLock()
    private let attestationMode: BackendAttestationMode
    private let settingsManager: SettingsManagerProtocol

    private var currentRemoteState: AnalyticsRemoteState
    private var observers: [ObserverWrapper] = []

    public init(attestationMode: BackendAttestationMode, settingsManager: SettingsManagerProtocol) {
        self.attestationMode = attestationMode
        self.settingsManager = settingsManager

        currentRemoteState = AnalyticsRemoteState(persisted: settingsManager.analyticsRemoteEnabled)
    }
}

// MARK: - Private

private extension AnalyticsAvailabilityProvider {
    var isAvailableLocked: Bool {
        attestationMode != .unavailable && currentRemoteState == .enabled
    }
}

private extension AnalyticsRemoteState {
    init(persisted: Bool?) {
        switch persisted {
        case .none:
            self = .unresolved
        case .some(true):
            self = .enabled
        case .some(false):
            self = .disabled
        }
    }
}

// MARK: - AnalyticsAvailabilityProviderProtocol

extension AnalyticsAvailabilityProvider: AnalyticsAvailabilityProviderProtocol {
    public var isAvailable: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return isAvailableLocked
    }

    public var remoteState: AnalyticsRemoteState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return currentRemoteState
    }

    public func setRemoteEnabled(_ enabled: Bool) {
        mutex.lock()

        let wasAvailable = isAvailableLocked

        currentRemoteState = enabled ? .enabled : .disabled
        settingsManager.analyticsRemoteEnabled = enabled

        let isAvailable = isAvailableLocked

        guard wasAvailable != isAvailable else {
            mutex.unlock()
            return
        }

        observers = observers.filter { $0.owner != nil }
        let recipients = observers

        mutex.unlock()

        recipients.forEach { wrapper in
            guard wrapper.owner != nil else {
                return
            }

            dispatchInQueueWhenPossible(wrapper.queue) {
                wrapper.closure(isAvailable)
            }
        }
    }

    public func addObserver(
        with owner: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (Bool) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        observers.append(ObserverWrapper(owner: owner, closure: closure, queue: queue))

        observers = observers.filter { $0.owner != nil }
    }

    public func removeObserver(by owner: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        observers = observers.filter { $0.owner !== owner && $0.owner != nil }
    }
}
