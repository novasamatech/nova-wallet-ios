import Foundation

struct ProxyDefinition: Decodable, Equatable {
    let definition: [Proxy.ProxyDefinition]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        definition = try container.decode([Proxy.ProxyDefinition].self)
    }

    init(definition: [Proxy.ProxyDefinition]) {
        self.definition = definition
    }
}
