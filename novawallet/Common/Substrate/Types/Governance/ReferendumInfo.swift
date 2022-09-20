import Foundation
import SubstrateSdk

enum ReferendumInfo: Decodable {
    struct OngoingStatus: Decodable {
        @StringCodable var track: Governance.TrackId
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
    let referendumIndex: Governance.ReferendumIndex

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
            to: StringScaleMapper<Governance.ReferendumIndex>.self,
            with: context
        ).value
    }
}
