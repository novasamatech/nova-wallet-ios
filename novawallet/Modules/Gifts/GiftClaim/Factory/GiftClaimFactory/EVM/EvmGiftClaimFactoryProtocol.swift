import Foundation
import Operation_iOS

protocol EvmGiftClaimFactoryProtocol {
    func createClaimWrapper(
        giftDescription: ClaimableGiftDescription,
        evmFee: EvmFeeModel,
        transferType: EvmTransferType
    ) -> CompoundOperationWrapper<Void>

    func createReclaimWrapper(
        gift: GiftModel,
        claimingAccountId: AccountId,
        evmFee: EvmFeeModel,
        transferType: EvmTransferType
    ) -> CompoundOperationWrapper<Void>
}
