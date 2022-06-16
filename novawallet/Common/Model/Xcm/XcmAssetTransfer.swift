import Foundation

struct XcmAssetTransfer {
    let destination: XcmAssetTransfer.Destination
    let reserveFee: XcmAssetTransferFee?
    let type: TransferType
}

extension XcmAssetTransfer {
    struct Destination {
        let chainId: ChainModel.Id
        let assetId: AssetModel.Id
        let fee: XcmAssetTransferFee
    }

    enum TransferType: String, Decodable {
        case xtokens
        case xcmpallet
    }
}
