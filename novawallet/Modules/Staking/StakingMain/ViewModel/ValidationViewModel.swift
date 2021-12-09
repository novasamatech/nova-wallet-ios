import Foundation

enum ValidationViewStatus {
    case undefined
    case active(era: UInt32)
    case inactive(era: UInt32)
}

struct ValidationViewModel {
    let totalStakedAmount: String
    let totalStakedPrice: String
    let status: ValidationViewStatus
    let hasPrice: Bool
}
