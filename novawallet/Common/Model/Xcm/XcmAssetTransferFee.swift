import Foundation

struct XcmAssetTransferFee: Decodable {
    enum FeeType: String, Decodable {
        case proportional
        case standard
    }

    struct Mode: Decodable {
        let type: XcmAssetTransferFee.FeeType
        let value: String?
    }

    let mode: XcmAssetTransferFee.Mode
    let instructions: String
}
