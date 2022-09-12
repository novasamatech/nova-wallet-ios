import Foundation
import BigInt

struct ParaStkYieldBoostConfirmModel {
    let collator: AccountId
    let accountMinimum: Decimal
    let period: UInt
    let executionTime: AutomationTime.UnixTime
    let collatorIdentity: AccountIdentity?
}
