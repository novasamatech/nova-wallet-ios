import Foundation

struct XcmChain: Decodable {
    let chainId: ChainModel.Id
    let assets: [XcmAsset]
}
