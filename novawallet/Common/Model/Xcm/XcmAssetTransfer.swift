import Foundation

struct XcmAssetTransfer: Decodable {
    let destination: XcmAssetTransfer.Destination
    let type: TransferType
}

extension XcmAssetTransfer {
    struct Destination: Decodable {
        let chainId: ChainModel.Id
        let assetId: AssetModel.Id
        let fee: XcmAssetTransferFee
    }

    enum TransferType: String, Decodable {
        case xtokens
        case xcmpallet
    }
}
