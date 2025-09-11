import Foundation

struct XcmCustomTeleport: Equatable, Hashable, Decodable {
    let originChain: ChainModel.Id
    let destChain: ChainModel.Id
    let originAsset: AssetModel.Id
}
