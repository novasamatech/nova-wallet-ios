import Foundation

struct ChainNodeModel: Equatable, Codable, Hashable {
    enum Feature: String, Codable, Hashable {
        case alchemyApi
        case noTls12
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

    init(
        url: String,
        name: String,
        order: Int16,
        features: Set<Feature>?,
        source: Source
    ) {
        self.url = url
        self.name = name
        self.order = order
        self.features = features
        self.source = source
    }
}

extension ChainNodeModel {
    var supportsTls12: Bool {
        !(features ?? []).contains(.noTls12)
    }
}
