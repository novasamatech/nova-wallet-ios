import Foundation

struct ReferendumLockReuseViewModel {
    let governance: String?
    let all: String?

    var hasLocks: Bool {
        governance != nil || all != nil
    }
}
