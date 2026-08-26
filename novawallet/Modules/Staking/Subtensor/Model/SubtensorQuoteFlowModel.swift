import BigInt
import Foundation

struct SubtensorQuoteFlowModel: Equatable {
    private(set) var args: SubtensorQuoteArgs?
    private(set) var quote: SubtensorQuote?

    static func stakeArgs(
        for target: SubtensorStakeTarget,
        amount: Balance?
    ) -> SubtensorQuoteArgs? {
        guard case let .subnet(info, _) = target, let amount, amount > 0 else {
            return nil
        }

        return SubtensorQuoteArgs(netuid: info.netuid, direction: .stake(taoIn: amount))
    }

    static func unstakeArgs(
        for target: SubtensorStakeTarget,
        amount: Balance?
    ) -> SubtensorQuoteArgs? {
        guard case let .subnet(info, _) = target, let amount, amount > 0 else {
            return nil
        }

        return SubtensorQuoteArgs(netuid: info.netuid, direction: .unstake(alphaIn: amount))
    }

    mutating func updateArgs(_ newArgs: SubtensorQuoteArgs?) -> SubtensorQuoteArgs? {
        guard newArgs != args else {
            return nil
        }

        args = newArgs
        quote = nil

        return newArgs
    }

    mutating func applyQuote(_ newQuote: SubtensorQuote) -> Bool {
        guard newQuote.args == args else {
            return false
        }

        quote = newQuote

        return true
    }

    /// a failed refresh must not leave the previous quote validating as fresh
    mutating func clearQuote() {
        quote = nil
    }

    var freshQuote: SubtensorQuote? {
        guard let quote, quote.args == args else {
            return nil
        }

        return quote
    }
}
