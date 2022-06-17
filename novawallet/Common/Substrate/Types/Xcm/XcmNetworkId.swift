import Foundation
import SubstrateSdk

extension Xcm {
    enum NetworkId: Encodable {
        case any
        case named(_ data: Data)
        case polkadot
        case kusama

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case .any:
                try container.encode("Any")
            case let .named(data):
                try container.encode("Named")
                try container.encode(BytesCodable(wrappedValue: data))
            case .polkadot:
                try container.encode("Polkadot")
            case .kusama:
                try container.encode("Kusama")
            }
        }
    }
}
