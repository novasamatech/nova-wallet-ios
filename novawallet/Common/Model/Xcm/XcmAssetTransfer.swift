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

    enum TransferTypeError: Error {
        case unknownType
    }

    enum TransferType: String, Decodable {
        case xtokens
        case xcmpallet
        case teleport = "xcmpallet-teleport"
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            let rawType = try container.decode(String.self)

            switch rawType {
            case Self.xtokens.rawValue:
                self = .xtokens
            case Self.xcmpallet.rawValue:
                self = .xcmpallet
            case Self.teleport.rawValue:
                self = .teleport
            default:
                self = .unknown
            }
        }
    }
}
