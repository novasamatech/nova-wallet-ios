import Foundation
import Operation_iOS
import NovaAppAttest

// Availability is fixed for the process: it depends only on whether this device and build can
// attest at all. The observer API is kept because the consent manager and the settings screens
// subscribe through it; nothing fires, because nothing can change it mid-process.
public final class AnalyticsAvailabilityProvider {
    private struct ObserverWrapper {
        weak var owner: AnyObject?
        let closure: (Bool) -> Void
        let queue: DispatchQueue?
    }

    private let mutex = NSLock()
    private let attestationMode: BackendAttestationMode

    private var observers: [ObserverWrapper] = []

    public init(attestationMode: BackendAttestationMode) {
        self.attestationMode = attestationMode
    }
}

// MARK: - AnalyticsAvailabilityProviderProtocol

extension AnalyticsAvailabilityProvider: AnalyticsAvailabilityProviderProtocol {
    public var isAvailable: Bool {
        attestationMode != .unavailable
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
