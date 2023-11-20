import Foundation
import BigInt
import SubstrateSdk

struct ExtrinsicProcessingResult {
    struct Swap {
        let assetIdIn: AssetModel.Id
        let assetIdOut: AssetModel.Id
        let amountIn: BigUInt
        let amountOut: BigUInt
    }

    let sender: AccountId
    let callPath: CallCodingPath
    let call: JSON
    let extrinsicHash: Data?
    let fee: BigUInt?
    let feeAssetId: AssetModel.Id?
    let peerId: AccountId?
    let amount: BigUInt?
    let isSuccess: Bool
    let assetId: AssetModel.Id?
    let swap: Swap?
}
