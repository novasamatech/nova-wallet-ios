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
    let migrationInProgress: Bool
    let wikiURL: URL
}

extension AHMRemoteData.ChainData {
    enum CodingKeys: String, CodingKey {
        case chainId
        case assetId
        case minBalance
        case averageFee
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        chainId = try container.decode(ChainModel.Id.self, forKey: .chainId)
        assetId = try container.decode(AssetModel.Id.self, forKey: .assetId)
        minBalance = try container.decodeHex(BigUInt.self, forKey: .minBalance)
        averageFee = try container.decodeHex(BigUInt.self, forKey: .averageFee)
    }
}
