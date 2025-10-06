import Foundation
import SubstrateSdk
import BigInt

enum SubqueryRewardType: String, SubqueryFilterValue {
    case reward
    case slash

    func rawSubqueryFilter() -> String { rawValue }
}

struct SubqueryRewardItemData: Equatable, Codable {
    let eventId: String
    let timestamp: Int64
    let validatorAddress: AccountAddress
    let era: Staking.EraIndex
    let stashAddress: AccountAddress
    let amount: BigUInt
    let isReward: Bool
}

extension SubqueryRewardItemData {
    init?(from json: JSON) {
        guard
            let eventId = json.id?.stringValue,
            let timestampString = json.timestamp?.stringValue,
            let timestamp = Int64(timestampString),
            let validatorAddress = json.reward?.validator?.stringValue,
            let stashAddress = json.address?.stringValue,
            let isReward = json.reward?.isReward?.boolValue,
            let era = json.reward?.era?.unsignedIntValue,
            let amountString = json.reward?.amount?.stringValue,
            let amount = BigUInt(amountString)
        else { return nil }

        self.eventId = eventId
        self.timestamp = timestamp
        self.validatorAddress = validatorAddress
        self.era = Staking.EraIndex(era)
        self.stashAddress = stashAddress
        self.amount = amount
        self.isReward = isReward
    }
}

struct SubqueryTotalRewardsData: Decodable {
    struct AccumulatedSum: Decodable {
        struct Sum: Decodable {
            let amount: String
        }

        let sum: Sum
    }

    let rewards: SubqueryAggregates<AccumulatedSum>
    let slashes: SubqueryAggregates<AccumulatedSum>
}
