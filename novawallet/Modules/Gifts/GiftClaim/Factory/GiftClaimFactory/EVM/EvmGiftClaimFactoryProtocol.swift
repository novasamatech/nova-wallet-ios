import Foundation
import Operation_iOS

protocol EvmGiftClaimFactoryProtocol {
    func createClaimWrapper(
        giftDescription: ClaimableGiftDescription,
        evmFee: EvmFeeModel,
        transferType: EvmGiftTransferInteractor.TransferType
    ) -> CompoundOperationWrapper<Void>
}
