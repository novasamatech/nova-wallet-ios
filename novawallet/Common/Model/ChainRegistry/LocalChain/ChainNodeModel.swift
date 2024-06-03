import Foundation

struct ChainNodeModel: Equatable, Codable, Hashable {
    enum Feature: String, Codable, Hashable {
        case alchemyApi
        case noTls12
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
}

extension ChainNodeModel {
    var supportsTls12: Bool {
        !(features ?? []).contains(.noTls12)
    }
}
