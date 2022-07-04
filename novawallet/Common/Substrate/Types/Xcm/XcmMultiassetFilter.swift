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

    // swiftlint:disable nesting
    enum WildMultiasset: Encodable {
        struct AllOfValue: Encodable {
            enum CodingKeys: String, CodingKey {
                case assetId = "id"
                case fun
            }

            let assetId: AssetId
            let fun: WildFungibility
        }

        case all
        case allOf(AllOfValue)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case .all:
                try container.encode("All")
                try container.encode(JSON.null)
            case let .allOf(value):
                try container.encode("AllOf")
                try container.encode(value)
            }
        }
    }

    // swiftlint:enable nesting

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
