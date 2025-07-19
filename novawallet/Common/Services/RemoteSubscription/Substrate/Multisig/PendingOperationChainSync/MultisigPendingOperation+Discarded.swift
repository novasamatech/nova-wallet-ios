import Foundation

/**
 *  There might be cases when an operation appears in one block
 *  but later the block was discarded and current on chain states returns nil definition.
 *  We must not treat such operation as completed
 *  since the corresponding transaction might be included into another block.
 *
 *  Current solution is to introduce a delay that prevents pending operation removal
 *  in case we receive nil definition a little bit later after operation is discovered.
 *
 *  1 minute should be enough for the operations without definition to settle onchain.
 */
extension Multisig.PendingOperation {
    static let expirationTimeout: TimeInterval = 60

    var isDiscoveredButPendingOnchain: Bool {
        guard !hasDefinition else {
            return false
        }

        let currentTimestamp = Date().timeIntervalSince1970

        return currentTimestamp - TimeInterval(timestamp) < Self.expirationTimeout
    }
}
