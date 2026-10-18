import Foundation
import Operation_iOS

public final class AnalyticsAvailabilityProvider {
    private struct ObserverWrapper {
        weak var owner: AnyObject?
        let closure: (Bool) -> Void
        let queue: DispatchQueue?
    }

    private let mutex = NSLock()
    private let isAuthSupported: Bool

    private var observers: [ObserverWrapper] = []

    public init(isAuthSupported: Bool) {
        self.isAuthSupported = isAuthSupported
    }
}

// MARK: - AnalyticsAvailabilityProviderProtocol

extension AnalyticsAvailabilityProvider: AnalyticsAvailabilityProviderProtocol {
    public var isAvailable: Bool {
        isAuthSupported
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
