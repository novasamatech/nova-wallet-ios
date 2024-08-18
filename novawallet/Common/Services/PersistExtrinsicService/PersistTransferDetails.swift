import Foundation
import BigInt

struct PersistTransferDetails {
    let sender: AccountAddress
    let receiver: AccountAddress
    let amount: BigUInt
    let txHash: Data
    let callPath: CallCodingPath
    let fee: BigUInt?
    let feeAssetId: AssetModel.Id?
}

struct PersistExtrinsicDetails {
    let sender: AccountAddress
    let txHash: Data
    let callPath: CallCodingPath
    let fee: BigUInt?
}

struct PersistSwapDetails {
    let txHash: Data
    let sender: AccountAddress
    let receiver: AccountAddress
    let assetIdIn: ChainAssetId
    let amountIn: BigUInt
    let assetIdOut: ChainAssetId
    let amountOut: BigUInt
    let fee: BigUInt?
    let feeAssetId: AssetModel.Id
    let callPath: CallCodingPath
}
