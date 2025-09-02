import Foundation

struct XcmDynamicChain: Decodable {
    let chainId: ChainModel.Id
    let assets: [XcmDynamicAsset]
}
