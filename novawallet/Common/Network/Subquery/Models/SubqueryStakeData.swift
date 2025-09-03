import Foundation
import SubstrateSdk
import BigInt

struct SubqueryStakeChangeData {
    let eventId: String
    let timestamp: Int64
    let address: AccountAddress
    let amount: BigUInt
    let accumulatedAmount: BigUInt
    let type: SubqueryStakeChangeType

    enum SubqueryStakeChangeType: String {
        case bonded
        case unbonded
        case slashed
        case rewarded
    }

    init?(from json: JSON?) {
        guard
            let json = json,
            let eventId = json.id?.stringValue,
            let timestampString = json.timestamp?.stringValue,
            let timestamp = Int64(timestampString),
            let address = json.address?.stringValue,
            let amountString = json.amount?.stringValue,
            let amount = BigUInt(amountString),
            let accumulatedAmountString = json.accumulatedAmount?.stringValue,
            let accumulatedAmount = BigUInt(accumulatedAmountString),
            let typeString = json.type?.stringValue,
            let type = SubqueryStakeChangeType(rawValue: typeString)
        else { return nil }

        self.eventId = eventId
        self.timestamp = timestamp
        self.address = address
        self.amount = amount
        self.accumulatedAmount = accumulatedAmount
        self.type = type
    }
}

extension SubqueryStakeChangeData.SubqueryStakeChangeType {
    func title(for locale: Locale) -> String {
        switch self {
        case .bonded:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingBondMore_v190()
        case .unbonded:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingUnbond_v190()
        case .rewarded:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingReward()
        case .slashed:
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSlash()
        }
    }
}
