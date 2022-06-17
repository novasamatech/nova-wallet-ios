import Foundation

extension Xcm {
    // swiftlint:disable identifier_name
    enum VersionedMultiasset: Encodable {
        case V1(Xcm.Multiasset)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .V1(multiasset):
                try container.encode("V1")
                try container.encode(multiasset)
            }
        }
    }
    // swiftlint:enable identifier_name
}
