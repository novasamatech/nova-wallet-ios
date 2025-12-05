import Foundation
import Operation_iOS
import BigInt

protocol EvmGiftSubmissionFactoryProtocol {
    func createSubmissionWrapper(
        amount: OnChainTransferAmount<BigUInt>,
        feeDescription: GiftFeeDescription?,
        evmFee: EvmFeeModel,
        transferType: EvmTransferType
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult>
}
