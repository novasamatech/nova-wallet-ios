import Foundation

extension Xcm {
    // swiftlint:disable identifier_name
    enum VersionedMultiasset: Codable {
        case V1(Xcm.Multiasset)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .V1(multiasset):
                try container.encode("V1")
                try container.encode(multiasset)
            }
        }

        init(from _: Decoder) throws {
            fatalError("Decoding unsupported")
        }
    }

    enum VersionedMultiassets: Codable {
        case V1([Xcm.Multiasset])

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .V1(multiassets):
                try container.encode("V1")
                try container.encode(multiassets)
            }
        }

        init(from _: Decoder) throws {
            fatalError("Decoding unsupported")
        }
    }

    // swiftlint:enable identifier_name
}
