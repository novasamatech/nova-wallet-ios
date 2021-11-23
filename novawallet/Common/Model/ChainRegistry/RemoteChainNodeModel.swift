import Foundation

struct RemoteChainNodeModel: Equatable, Codable, Hashable {
    let url: URL
    let name: String
    let apikey: ChainNodeModel.ApiKey?
}
