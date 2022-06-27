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

        func separatingDestinationBenifiary() -> (VersionedMultilocation, VersionedMultilocation) {
            switch self {
            case let .V1(fullMultilocation):
                let (destinationInterior, beneficiaryInterior) = fullMultilocation.interior.lastComponent()
                let destination = Xcm.Multilocation(
                    parents: fullMultilocation.parents,
                    interior: destinationInterior
                )

                let benefiary = Xcm.Multilocation(
                    parents: 0,
                    interior: beneficiaryInterior
                )

                return (.V1(destination), .V1(benefiary))
            }
        }
    }
    // swiftlint:enable identifier_name
}
