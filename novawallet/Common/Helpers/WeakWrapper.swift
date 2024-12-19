import Foundation

final class WeakWrapper {
    weak var target: AnyObject?

    init(target: AnyObject) {
        self.target = target
    }
}

extension Array where Element == WeakWrapper {
    mutating func clearEmptyItems() {
        self = filter { $0.target != nil }
    }
}

final class WeakObserver {
    weak var target: AnyObject?
    let notificationQueue: DispatchQueue
    let closure: () -> Void

    init(target: AnyObject, notificationQueue: DispatchQueue, closure: @escaping () -> Void) {
        self.target = target
        self.notificationQueue = notificationQueue
        self.closure = closure
    }
}

extension Array where Element == WeakObserver {
    mutating func clearEmptyItems() {
        self = filter { $0.target != nil }
    }
}
