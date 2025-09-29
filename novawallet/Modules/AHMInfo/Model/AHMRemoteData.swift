import Foundation
import BigInt

struct AHMRemoteData: Codable, Equatable {
    struct ChainData: Codable, Equatable {
        let chainId: ChainModel.Id
        let assetId: AssetModel.Id
        let minBalance: BigUInt
        let averageFee: BigUInt
    }

    let sourceData: ChainData
    let destinationData: ChainData
    let blockNumber: BlockNumber
    let timestamp: UInt64
    let newTokenNames: [String]
    let bannerPath: Banners.Domain
    let wikiURL: URL
}
