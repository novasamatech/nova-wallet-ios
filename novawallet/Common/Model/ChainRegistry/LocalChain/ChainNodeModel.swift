import Foundation

struct ChainNodeModel: Equatable, Codable, Hashable {
    let url: String
    let name: String
    let order: Int16

    init(url: String, name: String, order: Int16) {
        self.url = url
        self.name = name
        self.order = order
    }

    init(remoteModel: RemoteChainNodeModel, order: Int16) {
        url = remoteModel.url
        name = remoteModel.name
        self.order = order
    }
}
