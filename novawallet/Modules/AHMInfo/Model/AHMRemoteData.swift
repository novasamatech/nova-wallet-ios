import Foundation
import BigInt
import SubstrateSdk

struct AHMRemoteData: Codable, Equatable {
    struct ChainData: Codable, Equatable {
        let chainId: ChainModel.Id
        let assetId: AssetModel.Id
        @StringCodable var minBalance: BigUInt
        @StringCodable var averageFee: BigUInt
    }

    let sourceData: ChainData
    let destinationData: ChainData
    let blockNumber: BlockNumber
    let timestamp: UInt64
    let newTokenNames: [String]
    let bannerPath: Banners.Domain
    let migrationInProgress: Bool
    let wikiURL: URL
}
