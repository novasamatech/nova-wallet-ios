import Foundation

enum PayCardStatus {
    case pending(remained: TimeInterval, total: TimeInterval)
    case completed
    case failed

    var isCompleted: Bool {
        switch self {
        case .pending, .failed:
            false
        case .completed:
            true
        }
    }
}
