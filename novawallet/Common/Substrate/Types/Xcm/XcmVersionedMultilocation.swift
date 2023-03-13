import Foundation

extension Xcm {
    // swiftlint:disable identifier_name
    enum VersionedMultilocation: Codable {
        case V1(Xcm.Multilocation)
        case V2(Xcm.Multilocation)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .V1(multilocation):
                try container.encode("V1")
                try container.encode(multilocation)
            case let .V2(multilocation):
                try container.encode("V2")
                try container.encode(multilocation)
            }
        }

        init(from _: Decoder) throws {
            fatalError("Decoding unsupported")
        }

        private func getDestinationAndBeneficiary(
            from fullMultilocation: Xcm.Multilocation
        ) -> (Xcm.Multilocation, Xcm.Multilocation) {
            let (destinationInterior, beneficiaryInterior) = fullMultilocation.interior.lastComponent()
            let destination = Xcm.Multilocation(
                parents: fullMultilocation.parents,
                interior: destinationInterior
            )

            let benefiary = Xcm.Multilocation(
                parents: 0,
                interior: beneficiaryInterior
            )

            return (destination, benefiary)
        }

        func separatingDestinationBenifiary() -> (VersionedMultilocation, VersionedMultilocation) {
            switch self {
            case let .V1(fullMultilocation):
                let (destination, beneficiary) = getDestinationAndBeneficiary(from: fullMultilocation)
                return (.V1(destination), .V1(beneficiary))
            case let .V2(fullMultilocation):
                let (destination, beneficiary) = getDestinationAndBeneficiary(from: fullMultilocation)
                return (.V2(destination), .V1(beneficiary))
            }
        }
    }
    // swiftlint:enable identifier_name
}

extension Xcm.VersionedMultilocation {
    static func versionedMultiLocation(
        for version: Xcm.Version?,
        multiLocation: Xcm.Multilocation
    ) -> Xcm.VersionedMultilocation {
        guard let version = version else {
            return .V2(multiLocation)
        }

        if version <= .V1 {
            return .V1(multiLocation)
        } else {
            return .V2(multiLocation)
        }
    }
}
