import Foundation

struct XcmDynamicAssetTransfer: Decodable {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id
    let hasDeliveryFee: Bool?
}
