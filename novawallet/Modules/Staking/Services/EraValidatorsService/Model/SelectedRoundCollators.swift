import Foundation
import BigInt

struct CollatorInfo {
    let accountId: AccountId
    let snapshot: ParachainStaking.CollatorSnapshot
}

struct SelectedRoundCollators {
    let round: ParachainStaking.RoundIndex
    let commission: BigUInt
    let collators: [CollatorInfo]
}
