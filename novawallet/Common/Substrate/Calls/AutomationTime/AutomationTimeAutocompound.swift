import Foundation
import SubstrateSdk
import BigInt

extension AutomationTime {
    struct ScheduleAutocompoundCall: Codable {
        enum CodingKeys: String, CodingKey {
            case executionTime = "execution_time"
            case frequency
            case collatorId = "collator_id"
            case accountMinimum = "account_minimum"
        }

        @StringCodable var executionTime: AutomationTime.UnixTime
        @StringCodable var frequency: AutomationTime.Seconds
        let collatorId: AccountId
        @StringCodable var accountMinimum: BigUInt

        var runtimeCall: RuntimeCall<ScheduleAutocompoundCall> {
            RuntimeCall(moduleName: "AutomationTime", callName: "schedule_auto_compound_delegated_stake_task", args: self)
        }
    }
}
