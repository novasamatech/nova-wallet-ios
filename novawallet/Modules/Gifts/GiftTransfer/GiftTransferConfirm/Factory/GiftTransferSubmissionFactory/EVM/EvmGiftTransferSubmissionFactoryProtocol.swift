import Foundation
import Operation_iOS
import BigInt

protocol EvmGiftTransferSubmissionFactoryProtocol {
    func createSubmissionWrapper(
        amount: OnChainTransferAmount<BigUInt>,
        feeDescription: GiftFeeDescription?,
        evmFee: EvmFeeModel,
        transferType: EvmGiftTransferInteractor.TransferType
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult>
}
