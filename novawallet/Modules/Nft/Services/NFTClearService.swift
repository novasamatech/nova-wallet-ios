import Foundation
import Operation_iOS

/**
 *  The service accepts a repository that is filtered by nfts types to exclude (see base service).
 *  Then it returns empty remote list and base service undestands that local nfts must be removed.
 */
final class NFTClearService: BaseNftSyncService {
    override func createRemoteFetchWrapper() -> CompoundOperationWrapper<[RemoteNftModel]> {
        CompoundOperationWrapper.createWithResult([])
    }
}
