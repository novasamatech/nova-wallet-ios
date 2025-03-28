import Foundation

struct DAppOperationProcessedResult {
    let account: ChainAccountResponse
    let extrinsic: DAppParsedExtrinsic
    let feeAsset: ChainAsset?
}
