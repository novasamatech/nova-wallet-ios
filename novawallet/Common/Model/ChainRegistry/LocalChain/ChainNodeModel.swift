import Foundation

struct ChainNodeModel: Equatable, Codable, Hashable {
    enum Feature: String, Codable, Hashable {
        case alchemyApi
    }

    let url: String
    let name: String
    let order: Int16
    let features: Set<Feature>?

    init(url: String, name: String, order: Int16, features: Set<Feature>?) {
        self.url = url
        self.name = name
        self.order = order
        self.features = features
    }

    init(remoteModel: RemoteChainNodeModel, order: Int16) {
        url = remoteModel.url
        name = remoteModel.name
        self.order = order
        features = remoteModel.features.flatMap { Set($0.compactMap { Feature(rawValue: $0) }) }
    }
}
