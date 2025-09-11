import Foundation

struct XcmAssetTransfer: Decodable {
    let destination: XcmAssetTransfer.Destination
    let type: XcmCallType
}

extension XcmAssetTransfer {
    struct Destination: Decodable {
        let chainId: ChainModel.Id
        let assetId: AssetModel.Id
        let fee: XcmAssetTransferFee
    }
}
