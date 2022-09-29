import Foundation
import SubstrateSdk

enum ReferendumInfo: Decodable {
    struct DecidingStatus: Decodable {
        @StringCodable var since: BlockNumber
        @OptionStringCodable var confirming: BlockNumber?
    }

    struct OngoingStatus: Decodable {
        @StringCodable var track: Referenda.TrackId
        @BytesCodable var proposalHash: Data
        let enactment: OnChainScheduler.DispatchTime
        @StringCodable var submitted: Moment
        let decisionDeposit: Referenda.Deposit?
        let deciding: DecidingStatus?
        let tally: ConvictionVoting.Tally
        let inQueue: Bool
    }

    case ongoing(_ status: OngoingStatus)
    case approved
    case rejected
    case cancelled
    case timedOut
    case killed
    case unknown

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case "Ongoing":
            let status = try container.decode(OngoingStatus.self)
            self = .ongoing(status)
        case "Approved":
            self = .approved
        case "Rejected":
            self = .rejected
        case "Cancelled":
            self = .cancelled
        case "TimedOut":
            self = .timedOut
        case "Killed":
            self = .killed
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
