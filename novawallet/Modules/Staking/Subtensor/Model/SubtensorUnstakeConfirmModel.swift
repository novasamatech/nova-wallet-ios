import Foundation

struct SubtensorUnstakeConfirmModel {
    let delegate: DisplayAddress
    let unstakeModel: SubtensorUnstakeModel
    var target: SubtensorStakeTarget = .root
    var slippage: BigRational?
    var quote: SubtensorQuote?
}
