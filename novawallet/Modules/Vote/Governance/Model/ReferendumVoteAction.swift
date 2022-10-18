import Foundation
import BigInt

struct ReferendumVoteAction: Hashable {
    let amount: BigUInt
    let conviction: ConvictionVoting.Conviction
    let isAye: Bool
}
