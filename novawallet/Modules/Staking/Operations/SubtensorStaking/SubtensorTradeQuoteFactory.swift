import BigInt
import Foundation
import Operation_iOS

final class SubtensorTradeQuoteFactory {
    let quoteFactory: SubtensorQuoteOperationFactoryProtocol
    let feeCalculator: SubtensorNovaFeeCalculator

    init(
        quoteFactory: SubtensorQuoteOperationFactoryProtocol,
        feeCalculator: SubtensorNovaFeeCalculator = SubtensorNovaFeeCalculator()
    ) {
        self.quoteFactory = quoteFactory
        self.feeCalculator = feeCalculator
    }
}

private extension SubtensorTradeQuoteFactory {
    static func ensureSubnet(_ netuid: UInt16) throws {
        guard netuid != SubtensorStakingPallet.rootNetuid else {
            throw SubtensorStakingOperationError.limitOnRootOrder
        }
    }

    static func netOfPoolFee(_ amount: Balance, feeRate: UInt16) -> Balance {
        let poolFee = amount * BigUInt(feeRate) / BigUInt(SubtensorStakingPallet.perU16Denominator)

        return amount - poolFee
    }

    static func makeBuyQuote(
        from quote: SubtensorQuote,
        stakedTao: Balance,
        novaFee: SubtensorNovaFee?,
        tolerance: BigRational
    ) throws -> SubtensorTradeQuote {
        let limitPrice = try SubtensorLimitPriceCalculator.buyLimit(spot: quote.spotPrice, tolerance: tolerance)
        let swappedTao = netOfPoolFee(stakedTao, feeRate: quote.feeRate)
        let minimumAlphaOut = swappedTao * SubtensorStakingPallet.alphaPriceScale / limitPrice

        try SubtensorStakingPallet.ensureU64Amount(minimumAlphaOut)

        return SubtensorTradeQuote(
            quote: quote,
            novaFee: novaFee,
            expectedOut: quote.expectedOut,
            minimumOut: minimumAlphaOut,
            limitPrice: limitPrice
        )
    }

    static func makeSellQuote(
        from quote: SubtensorQuote,
        alpha: Balance,
        tolerance: BigRational,
        feeCalculator: SubtensorNovaFeeCalculator
    ) throws -> SubtensorTradeQuote {
        let limitPrice = try SubtensorLimitPriceCalculator.sellLimit(spot: quote.spotPrice, tolerance: tolerance)
        let novaFee = try feeCalculator.sellFee(quotedTaoOut: quote.sim.taoAmount)
        let feeAmount = novaFee?.amount ?? 0
        let swappedAlpha = netOfPoolFee(alpha, feeRate: quote.feeRate)
        let minimumTaoOut = try SubtensorNovaFeeCalculator.minimumTaoOut(alpha: swappedAlpha, limitPrice: limitPrice)

        return SubtensorTradeQuote(
            quote: quote,
            novaFee: novaFee,
            expectedOut: quote.expectedOut > feeAmount ? quote.expectedOut - feeAmount : 0,
            minimumOut: minimumTaoOut > feeAmount ? minimumTaoOut - feeAmount : 0,
            limitPrice: limitPrice
        )
    }
}

extension SubtensorTradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol {
    func createBuyQuoteWrapper(
        netuid: UInt16,
        grossTao: Balance,
        tolerance: BigRational
    ) -> CompoundOperationWrapper<SubtensorTradeQuote> {
        do {
            try Self.ensureSubnet(netuid)

            let novaFee = try feeCalculator.buyFee(grossTao: grossTao)
            let feeAmount = novaFee?.amount ?? 0
            let stakedTao = grossTao > feeAmount ? grossTao - feeAmount : 0

            let quoteWrapper = quoteFactory.createQuoteWrapper(
                for: SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: stakedTao))
            )

            let mappingOperation = ClosureOperation<SubtensorTradeQuote> {
                let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()

                return try Self.makeBuyQuote(from: quote, stakedTao: stakedTao, novaFee: novaFee, tolerance: tolerance)
            }

            mappingOperation.addDependency(quoteWrapper.targetOperation)

            return quoteWrapper.insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
    }

    func createSellQuoteWrapper(
        netuid: UInt16,
        alpha: Balance,
        tolerance: BigRational
    ) -> CompoundOperationWrapper<SubtensorTradeQuote> {
        do {
            try Self.ensureSubnet(netuid)

            guard feeCalculator.beneficiary != nil else {
                throw SubtensorStakingOperationError.novaFeeUnavailable
            }

            let quoteWrapper = quoteFactory.createQuoteWrapper(
                for: SubtensorQuoteArgs(netuid: netuid, direction: .unstake(alphaIn: alpha))
            )

            let mappingOperation = ClosureOperation<SubtensorTradeQuote> { [feeCalculator] in
                let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()

                return try Self.makeSellQuote(
                    from: quote,
                    alpha: alpha,
                    tolerance: tolerance,
                    feeCalculator: feeCalculator
                )
            }

            mappingOperation.addDependency(quoteWrapper.targetOperation)

            return quoteWrapper.insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
