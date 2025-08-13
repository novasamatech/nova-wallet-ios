import Foundation

enum LedgerInvaliDataPolkadotReason {
    case unknown(reason: String)
    case unsupportedOperation
    case outdatedMetadata

    init(rawReason: String) {
        switch rawReason {
        case "Not supported":
            self = .unsupportedOperation
        case "Method not supported":
            self = .unsupportedOperation
        case "Unexpected module index":
            self = .unsupportedOperation
        case "Call nesting not supported":
            self = .unsupportedOperation
        case "Spec version not supported":
            self = .outdatedMetadata
        case "Txn version not supported":
            self = .outdatedMetadata
        default:
            self = .unknown(reason: rawReason)
        }
    }
}
