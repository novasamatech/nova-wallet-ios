import Foundation
import Operation_iOS
import BigInt

protocol GiftTransferSubmissionFactoryProtocol {
    func createSubmissionWrapper(
        amount: OnChainTransferAmount<BigUInt>,
        assetStorageInfo: AssetStorageInfo?,
        feeDescription: GiftFeeDescription?
    ) -> CompoundOperationWrapper<ExtrinsicSenderResolution?>
}
