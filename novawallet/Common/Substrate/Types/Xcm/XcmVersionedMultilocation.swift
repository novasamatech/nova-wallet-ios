import Foundation

extension Xcm {
    // swiftlint:disable identifier_name
    enum VersionedMultilocation: Encodable {
        case V1(Xcm.Multilocation)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .V1(multilocation):
                try container.encode("V1")
                try container.encode(multilocation)
            }
        }
    }
    // swiftlint:enable identifier_name
}
