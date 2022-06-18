import Foundation
import SubstrateSdk

extension Xcm {
    enum AssetId: Encodable {
        case concrete(Multilocation)
        case abstract(Data)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .concrete(multilocation):
                try container.encode("Concrete")
                try container.encode(multilocation)
            case let .abstract(data):
                try container.encode("Abstract")
                try container.encode(BytesCodable(wrappedValue: data))
            }
        }
    }

    enum WildFungibility: Int, Encodable {
        case fungible
        case nonFungible

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(rawValue)
        }
    }

    enum WildMultiasset: Encodable {
        case all
        case allOf(AssetId, WildFungibility)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case .all:
                try container.encode("All")
            case let .allOf(assetId, wildFungibility):
                try container.encode("AllOf")
                try container.encode(assetId)
                try container.encode(wildFungibility)
            }
        }
    }

    enum MultiassetFilter: Encodable {
        case definite([Multiasset])
        case wild(WildMultiasset)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .definite(multiassets):
                try container.encode("Definite")
                try container.encode(multiassets)
            case let .wild(wildMultiasset):
                try container.encode("Wild")
                try container.encode(wildMultiasset)
            }
        }
    }
}
