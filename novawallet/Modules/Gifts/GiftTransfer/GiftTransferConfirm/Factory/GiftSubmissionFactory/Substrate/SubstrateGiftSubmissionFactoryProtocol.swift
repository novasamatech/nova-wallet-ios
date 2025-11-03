import Foundation
import Operation_iOS
import BigInt

protocol SubstrateGiftSubmissionFactoryProtocol {
    func createSubmissionWrapper(
        amount: OnChainTransferAmount<BigUInt>,
        assetStorageInfo: AssetStorageInfo?,
        feeDescription: GiftFeeDescription?
    ) -> CompoundOperationWrapper<GiftTransferSubmissionResult>
}
