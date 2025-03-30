import Foundation

extension Xcm {
    // swiftlint:disable identifier_name
    enum VersionedMultilocation: Codable, Equatable {
        case V1(Xcm.Multilocation)
        case V2(Xcm.Multilocation)
        case V3(XcmV3.Multilocation)
        case V4(XcmV4.Multilocation)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .V1(multilocation):
                try container.encode("V1")
                try container.encode(multilocation)
            case let .V2(multilocation):
                try container.encode("V2")
                try container.encode(multilocation)
            case let .V3(multilocation):
                try container.encode("V3")
                try container.encode(multilocation)
            case let .V4(multilocation):
                try container.encode("V4")
                try container.encode(multilocation)
            }
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "V1":
                let multilocation = try container.decode(Xcm.Multilocation.self)
                self = .V1(multilocation)
            case "V2":
                let multilocation = try container.decode(Xcm.Multilocation.self)
                self = .V2(multilocation)
            case "V3":
                let multilocation = try container.decode(XcmV3.Multilocation.self)
                self = .V3(multilocation)
            case "V4":
                let multilocation = try container.decode(XcmV4.Multilocation.self)
                self = .V4(multilocation)
            default:
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "Unexpected version: \(type)"
                    )
                )
            }
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

        private func getV3DestinationAndBeneficiary(
            from fullMultilocation: XcmV3.Multilocation
        ) -> (XcmV3.Multilocation, XcmV3.Multilocation) {
            let (destinationInterior, beneficiaryInterior) = fullMultilocation.interior.lastComponent()
            let destination = XcmV3.Multilocation(
                parents: fullMultilocation.parents,
                interior: destinationInterior
            )

            let benefiary = XcmV3.Multilocation(
                parents: 0,
                interior: beneficiaryInterior
            )

            return (destination, benefiary)
        }

        private func getV4DestinationAndBeneficiary(
            from fullMultilocation: XcmV4.Multilocation
        ) -> (XcmV4.Multilocation, XcmV4.Multilocation) {
            let (destinationInterior, beneficiaryInterior) = fullMultilocation.interior.lastComponent()
            let destination = XcmV4.Multilocation(
                parents: fullMultilocation.parents,
                interior: destinationInterior
            )

            let benefiary = XcmV4.Multilocation(
                parents: 0,
                interior: beneficiaryInterior
            )

            return (destination, benefiary)
        }

        func separatingDestinationBenificiary() -> (VersionedMultilocation, VersionedMultilocation) {
            switch self {
            case let .V1(fullMultilocation):
                let (destination, beneficiary) = getDestinationAndBeneficiary(from: fullMultilocation)
                return (.V1(destination), .V1(beneficiary))
            case let .V2(fullMultilocation):
                let (destination, beneficiary) = getDestinationAndBeneficiary(from: fullMultilocation)
                return (.V2(destination), .V2(beneficiary))
            case let .V3(fullMultilocation):
                let (destination, beneficiary) = getV3DestinationAndBeneficiary(from: fullMultilocation)
                return (.V3(destination), .V3(beneficiary))
            case let .V4(fullMultilocation):
                let (destination, beneficiary) = getV4DestinationAndBeneficiary(from: fullMultilocation)
                return (.V4(destination), .V4(beneficiary))
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

    var version: Xcm.Version {
        switch self {
        case .V1:
            return .V1
        case .V2:
            return .V2
        case .V3:
            return .V3
        case .V4:
            return .V4
        }
    }
}
