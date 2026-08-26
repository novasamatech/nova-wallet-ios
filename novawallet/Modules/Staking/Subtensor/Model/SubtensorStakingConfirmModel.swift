import Foundation

struct SubtensorStakingConfirmModel {
    let delegate: DisplayAddress
    let delegateTake: UInt16?
    let stakeModel: SubtensorStakeModel
    let isStakeMore: Bool
    var target: SubtensorStakeTarget = .root
    var slippage: BigRational?
    var quote: SubtensorQuote?
}
