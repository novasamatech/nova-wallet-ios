import Foundation

struct ChainNodeModel: Equatable, Codable, Hashable {
    struct ApiKey: Equatable, Codable, Hashable {
        let queryName: String
        let keyName: String
    }

    let url: URL
    let name: String
    let apikey: ApiKey?
    let order: Int16

    init(url: URL, name: String, apikey: ApiKey?, order: Int16) {
        self.url = url
        self.name = name
        self.apikey = apikey
        self.order = order
    }

    init(remoteModel: RemoteChainNodeModel, order: Int16) {
        url = remoteModel.url
        name = remoteModel.name
        apikey = remoteModel.apikey
        self.order = order
    }
}
