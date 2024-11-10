import Foundation

enum SubstrateExtrinsicStatus {
    case success(ExtrinsicHash)
    case failure(ExtrinsicHash, DispatchExtrinsicError)
}
