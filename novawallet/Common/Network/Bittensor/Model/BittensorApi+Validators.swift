import Foundation

extension BittensorApi {
    struct ValidatorCollection: Decodable, Equatable {
        struct Components: Decodable, Equatable {
            let validatorStakes: ComponentMetadata
            let validatorMetagraph: ComponentMetadata
            let validatorIdentities: ComponentMetadata
        }

        struct Meta: Decodable, Equatable {
            let completeness: Completeness
            let components: Components
        }

        let items: [Validator]
        let meta: Meta
    }

    struct Validator: Decodable, Equatable {
        let netuid: UInt16
        let hotkey: String
        let stakeSourceName: String?
        let identitySourceName: String?
        let metagraphBlockNumber: UInt64?
        let metagraphUid: UInt16?
        let metagraphColdkey: String?
        let reportedMeasurements: ValidatorMeasurements
    }

    struct ValidatorMeasurements: Decodable, Equatable {
        let validatorStake: String?
        let metagraphStake: String?
        let reportedTaoStake: String?
        let reportedAlphaStake: String?
        let reportedNominatedStake: String?
        let reportedValidatorTrust: String?
        let reportedTrust: String?
        let reportedDividend: String?
        let reportedIncentive: String?
        let reportedEmission: String?
        let reportedTaoDividendsPerHotkey: String?
        let reportedAlphaDividendsPerHotkey: String?
    }
}

extension BittensorApi.ValidatorCollection.Components {
    private enum CodingKeys: String, CodingKey {
        case validatorStakes
        case validatorMetagraph
        case validatorIdentities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        validatorStakes = try Self.decodeComponent(
            forKey: .validatorStakes,
            allowedReasons: [.temporarilyUnavailable],
            in: container
        )

        validatorMetagraph = try Self.decodeComponent(
            forKey: .validatorMetagraph,
            allowedReasons: [.temporarilyUnavailable, .sourceNotSupported],
            in: container
        )

        validatorIdentities = try Self.decodeComponent(
            forKey: .validatorIdentities,
            allowedReasons: [.temporarilyUnavailable],
            in: container
        )
    }

    private static func decodeComponent(
        forKey key: CodingKeys,
        allowedReasons: Set<BittensorApi.AvailabilityReason>,
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> BittensorApi.ComponentMetadata {
        let component = try container.decode(BittensorApi.ComponentMetadata.self, forKey: key)

        if case let .unavailable(reason) = component, !allowedReasons.contains(reason) {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Availability reason \(reason.rawValue) is not allowed for \(key.stringValue)"
            )
        }

        return component
    }
}
