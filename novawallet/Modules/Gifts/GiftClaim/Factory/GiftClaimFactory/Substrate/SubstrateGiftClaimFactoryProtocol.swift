import Foundation
import Operation_iOS

protocol SubstrateGiftClaimFactoryProtocol {
    func createClaimWrapper(
        giftDescription: ClaimableGiftDescription,
        assetStorageInfo: AssetStorageInfo?
    ) -> CompoundOperationWrapper<Void>

    func createReclaimWrapper(
        gift: GiftModel,
        claimingAccountId: AccountId,
        assetStorageInfo: AssetStorageInfo?
    ) -> CompoundOperationWrapper<Void>
}
