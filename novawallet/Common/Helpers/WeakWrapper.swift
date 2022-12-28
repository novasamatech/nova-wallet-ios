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
