import Foundation

extension Xcm {
    // swiftlint:disable identifier_name
    enum VersionedMultilocation: Codable {
        case V1(Xcm.Multilocation)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .V1(multilocation):
                try container.encode("V1")
                try container.encode(multilocation)
            }
        }

        init(from _: Decoder) throws {
            fatalError("Decoding unsupported")
        }
    }
    // swiftlint:enable identifier_name
}
