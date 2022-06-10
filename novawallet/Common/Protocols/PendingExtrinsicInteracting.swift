import Foundation

protocol PendingExtrinsicInteracting: AnyObject {
    var extrinsicSubscriptionId: UInt16? { get }
}

extension PendingExtrinsicInteracting {
    var hasPendingExtrinsic: Bool {
        extrinsicSubscriptionId != nil
    }
}
