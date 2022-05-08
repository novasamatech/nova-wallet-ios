import Foundation
import BigInt

struct SelectedRoundCollators {
    let round: ParachainStaking.RoundIndex
    let commission: BigUInt
    let collators: [ParachainStaking.CollatorSnapshot]
}
