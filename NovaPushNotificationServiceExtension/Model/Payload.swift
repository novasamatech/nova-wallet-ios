import Foundation
import BigInt

struct StakingRewardPayload: Codable {
    let recipient: AccountAddress
    let amount: String
}

struct NewReleasePayload: Codable {
    let version: String
}

struct NewReferendumPayload: Codable {
    let referendumId: UInt

    var referendumNumber: String {
        "#\(referendumId)"
    }
}

struct ReferendumStateUpdatePayload: Codable {
    enum CodingKeys: String, CodingKey {
        case referendumId
        case fromStatus = "from"
        case toStatus = "to"
    }

    let referendumId: UInt
    let fromStatus: Status?
    let toStatus: Status

    enum Status: String, Codable {
        case created
        case deciding
        case confirming
        case approved
        case rejected
        case cancelled
        case timedOut
        case killed

        func description(for locale: Locale?) -> String {
            switch self {
            case .created:
                return R.string.localizable.pushNotificationReferendumCreated(preferredLanguages: locale?.rLanguages)
            case .deciding:
                return R.string.localizable.pushNotificationReferendumDeciding(preferredLanguages: locale?.rLanguages)
            case .confirming:
                return R.string.localizable.pushNotificationReferendumConfirming(preferredLanguages: locale?.rLanguages)
            case .approved:
                return R.string.localizable.pushNotificationReferendumApproved(preferredLanguages: locale?.rLanguages)
            case .rejected:
                return R.string.localizable.pushNotificationReferendumRejected(preferredLanguages: locale?.rLanguages)
            case .cancelled:
                return R.string.localizable.pushNotificationReferendumCancelled(preferredLanguages: locale?.rLanguages)
            case .timedOut:
                return R.string.localizable.pushNotificationReferendumTimedOut(preferredLanguages: locale?.rLanguages)
            case .killed:
                return R.string.localizable.pushNotificationReferendumKilled(preferredLanguages: locale?.rLanguages)
            }
        }
    }

    var referendumNumber: String {
        "#\(referendumId)"
    }
}

struct NotificationTransferPayload: Decodable {
    let sender: AccountAddress?
    let recipient: AccountAddress?
    let amount: String
    let assetId: String?
}
