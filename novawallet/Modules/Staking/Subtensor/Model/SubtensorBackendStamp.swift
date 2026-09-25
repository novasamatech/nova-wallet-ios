import Foundation

struct SubtensorBackendStamp: Equatable {
    enum Freshness: Equatable {
        case fresh
        case stale
    }

    let asOf: Date
    let freshness: Freshness
}
