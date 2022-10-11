import Foundation
import SubstrateSdk

enum ReferendumInfo: Decodable {
    struct DecidingStatus: Decodable {
        @StringCodable var since: BlockNumber
        @OptionStringCodable var confirming: BlockNumber?
    }

    struct OngoingStatus: Decodable {
        @StringCodable var track: Referenda.TrackId
        let proposal: SupportPallet.Bounded<RuntimeCall<JSON>>
        let enactment: OnChainScheduler.DispatchTime
        @StringCodable var submitted: Moment
        let submissionDeposit: Referenda.Deposit
        let decisionDeposit: Referenda.Deposit?
        let deciding: DecidingStatus?
        let tally: ConvictionVoting.Tally
        let inQueue: Bool
    }

    struct CompletedStatus: Decodable {
        enum CodingKeys: String, CodingKey {
            case since = "0"
            case submissionDeposit = "1"
            case decisionDeposit = "2"
        }

        @StringCodable var since: Moment
        let submissionDeposit: Referenda.Deposit
        let decisionDeposit: Referenda.Deposit?
    }

    case ongoing(OngoingStatus)
    case approved(CompletedStatus)
    case rejected(CompletedStatus)
    case cancelled(CompletedStatus)
    case timedOut(CompletedStatus)
    case killed(atBlock: Moment)
    case unknown

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case "Ongoing":
            let status = try container.decode(OngoingStatus.self)
            self = .ongoing(status)
        case "Approved":
            let status = try container.decode(CompletedStatus.self)
            self = .approved(status)
        case "Rejected":
            let status = try container.decode(CompletedStatus.self)
            self = .rejected(status)
        case "Cancelled":
            let status = try container.decode(CompletedStatus.self)
            self = .cancelled(status)
        case "TimedOut":
            let status = try container.decode(CompletedStatus.self)
            self = .timedOut(status)
        case "Killed":
            let since = try container.decode(StringScaleMapper<Moment>.self).value
            self = .killed(atBlock: since)
        default:
            self = .unknown
        }
    }
}

struct ReferendumIndexKey: JSONListConvertible, Hashable {
    let referendumIndex: Referenda.ReferendumIndex

    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
        let expectedFieldsCount = 1
        let actualFieldsCount = jsonList.count
        guard expectedFieldsCount == actualFieldsCount else {
            throw JSONListConvertibleError.unexpectedNumberOfItems(
                expected: expectedFieldsCount,
                actual: actualFieldsCount
            )
        }

        referendumIndex = try jsonList[0].map(
            to: StringScaleMapper<Referenda.ReferendumIndex>.self,
            with: context
        ).value
    }
}
