import Foundation

class BaseLocalSubscriptionFactory {
    private var providers: [String: WeakWrapper] = [:]
    private let mutex = NSLock()

    func saveProvider(_ provider: AnyObject, for key: String) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        providers[key] = WeakWrapper(target: provider)
    }

    func getProvider(for key: String) -> AnyObject? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return providers[key]?.target
    }

    func clearIfNeeded() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        providers = providers.filter { $0.value.target != nil }
    }
}
