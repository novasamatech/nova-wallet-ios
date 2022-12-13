import Foundation

struct RemoteChainExternalApiSet: Codable, Hashable {
    let staking: ChainModel.ExternalApi?
    let history: [RemoteTransactionHistoryApi]?
    let crowdloans: ChainModel.ExternalApi?
    let governance: ChainModel.ExternalApi?
}

struct RemoteTransactionHistoryApi: Codable, Hashable {
    let type: String
    let url: URL
    let assetType: String?
}
