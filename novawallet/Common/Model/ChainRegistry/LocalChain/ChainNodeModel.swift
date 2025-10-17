import Foundation

struct ChainNodeModel: Equatable, Codable, Hashable {
    enum Feature: String, Codable, Hashable {
        case alchemyApi
    }

    enum Source: String, Codable, Hashable {
        case user
        case remote
    }

    let url: String
    let name: String
    let order: Int16
    let features: Set<Feature>?
    let source: Source
}

extension ChainNodeModel {
    func updatingOrder(_ newOrder: Int16) -> ChainNodeModel {
        ChainNodeModel(
            url: url,
            name: name,
            order: newOrder,
            features: features,
            source: source
        )
    }

    func updating(
        _ url: String? = nil,
        _ name: String? = nil
    ) -> ChainNodeModel {
        ChainNodeModel(
            url: url ?? self.url,
            name: name ?? self.name,
            order: order,
            features: features,
            source: source
        )
    }
}
