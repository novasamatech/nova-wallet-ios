import Foundation

struct NotEqualWrapper<V>: Equatable {
    let value: V

    static func == (_: NotEqualWrapper<V>, _: NotEqualWrapper<V>) -> Bool {
        false
    }
}
