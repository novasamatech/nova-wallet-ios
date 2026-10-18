import BigInt
import Foundation
import Operation_iOS

final class SubtensorTradeQuoteFactory {
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let configProvider: SubtensorConfigProviding
    let operationQueue: OperationQueue
    let feeCalculator: SubtensorNovaFeeCalculator

    init(
        operationFactory: SubtensorApiOperationFactoryProtocol,
        configProvider: SubtensorConfigProviding,
        operationQueue: OperationQueue,
        feeCalculator: SubtensorNovaFeeCalculator = SubtensorNovaFeeCalculator()
    ) {
        self.operationFactory = operationFactory
        self.configProvider = configProvider
        self.operationQueue = operationQueue
        self.feeCalculator = feeCalculator
    }
}

extension SubtensorTradeQuoteFactory {
    static func sellSwapMinimumOut(alpha: Balance, feeRate: UInt16, limitPrice: Balance) throws -> Balance {
        try SubtensorNovaFeeCalculator.minimumTaoOut(
            alpha: netOfPoolFee(alpha, feeRate: feeRate),
            limitPrice: limitPrice
        )
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

    func createSimWrapper(
        for args: SubtensorQuoteArgs,
        blockHash: BlockHash
    ) -> CompoundOperationWrapper<SubtensorStakingPallet.SimSwapResult> {
        switch args.direction {
        case let .stake(taoIn):
            return operationFactory.createSimSwapTaoForAlphaWrapper(
                netuid: args.netuid,
                taoAmount: taoIn,
                blockHash: blockHash
            )
        case let .unstake(alphaIn):
            return operationFactory.createSimSwapAlphaForTaoWrapper(
                netuid: args.netuid,
                alphaAmount: alphaIn,
                blockHash: blockHash
            )
        }
    }

    func createPinnedQuoteWrapper(
        for args: SubtensorQuoteArgs,
        blockHash: BlockHash
    ) -> CompoundOperationWrapper<SubtensorQuote> {
        let simWrapper = createSimWrapper(for: args, blockHash: blockHash)
        let priceWrapper = operationFactory.createAlphaPriceWrapper(for: args.netuid, blockHash: blockHash)
        let feeRateWrapper = operationFactory.createFeeRateWrapper(for: args.netuid, blockHash: blockHash)

        let mergeOperation = ClosureOperation<SubtensorQuote> {
            let sim = try simWrapper.targetOperation.extractNoCancellableResultData()
            let spotPrice = try priceWrapper.targetOperation.extractNoCancellableResultData()
            let feeRate = try feeRateWrapper.targetOperation.extractNoCancellableResultData()

            guard spotPrice > 0 else {
                throw SubtensorQuoteError.missingSpotPrice(netuid: args.netuid)
            }

            let quote = SubtensorQuote(args: args, sim: sim, spotPrice: spotPrice, feeRate: feeRate)

            guard quote.expectedOut > 0 else {
                throw SubtensorQuoteError.quoteUnavailable(netuid: args.netuid)
            }

            return quote
        }

        mergeOperation.addDependency(simWrapper.targetOperation)
        mergeOperation.addDependency(priceWrapper.targetOperation)
        mergeOperation.addDependency(feeRateWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: simWrapper.allOperations + priceWrapper.allOperations + feeRateWrapper.allOperations
        )
    }

    func createQuoteWrapper(for args: SubtensorQuoteArgs) -> CompoundOperationWrapper<SubtensorQuote> {
        let blockHashWrapper = operationFactory.createBestBlockHashWrapper()

        let quoteWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let blockHash = try blockHashWrapper.targetOperation.extractNoCancellableResultData()

            return createPinnedQuoteWrapper(for: args, blockHash: blockHash)
        }

        quoteWrapper.addDependency(wrapper: blockHashWrapper)

        return quoteWrapper.insertingHead(operations: blockHashWrapper.allOperations)
    }

    static func makeBuyQuote(
        from quote: SubtensorQuote,
        grossTao: Balance,
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
            amountIn: grossTao,
            novaFee: novaFee,
            expectedOut: quote.expectedOut,
            swapMinimumOut: minimumAlphaOut,
            minimumOut: minimumAlphaOut,
            limitPrice: limitPrice
        )
    }

    static func makeSellQuote(
        from quote: SubtensorQuote,
        alpha: Balance,
        tolerance: BigRational,
        novaFee: SubtensorNovaFee?
    ) throws -> SubtensorTradeQuote {
        let limitPrice = try SubtensorLimitPriceCalculator.sellLimit(spot: quote.spotPrice, tolerance: tolerance)
        let feeAmount = novaFee?.amount ?? 0
        let minimumTaoOut = try sellSwapMinimumOut(alpha: alpha, feeRate: quote.feeRate, limitPrice: limitPrice)

        return SubtensorTradeQuote(
            quote: quote,
            amountIn: alpha,
            novaFee: novaFee,
            expectedOut: quote.expectedOut > feeAmount ? quote.expectedOut - feeAmount : 0,
            swapMinimumOut: minimumTaoOut,
            minimumOut: minimumTaoOut > feeAmount ? minimumTaoOut - feeAmount : 0,
            limitPrice: limitPrice
        )
    }
}

private extension SubtensorTradeQuoteFactory {
    func createBuyQuoteWrapper(
        netuid: UInt16,
        grossTao: Balance,
        tolerance: BigRational
    ) -> CompoundOperationWrapper<SubtensorTradeQuote> {
        do {
            try Self.ensureSubnet(netuid)
            try ensureBeneficiary()
        } catch {
            return .createWithError(error)
        }

        let rateWrapper = configProvider.createNovaFeeRateWrapper()

        let quoteWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let rate = try rateWrapper.targetOperation.extractNoCancellableResultData()
            let novaFee = try feeCalculator.fee(basis: grossTao, rate: rate)
            let feeAmount = novaFee?.amount ?? 0
            let stakedTao = grossTao > feeAmount ? grossTao - feeAmount : 0

            return createQuoteWrapper(
                for: SubtensorQuoteArgs(netuid: netuid, direction: .stake(taoIn: stakedTao))
            ).mapped { quote in
                try Self.makeBuyQuote(
                    from: quote,
                    grossTao: grossTao,
                    stakedTao: stakedTao,
                    novaFee: novaFee,
                    tolerance: tolerance
                )
            }
        }

        quoteWrapper.addDependency(wrapper: rateWrapper)

        return quoteWrapper.insertingHead(operations: rateWrapper.allOperations)
    }

    func createSellQuoteWrapper(
        netuid: UInt16,
        alpha: Balance,
        tolerance: BigRational
    ) -> CompoundOperationWrapper<SubtensorTradeQuote> {
        do {
            try Self.ensureSubnet(netuid)
            try ensureBeneficiary()
        } catch {
            return .createWithError(error)
        }

        let rateWrapper = configProvider.createNovaFeeRateWrapper()

        let quoteWrapper = createQuoteWrapper(
            for: SubtensorQuoteArgs(netuid: netuid, direction: .unstake(alphaIn: alpha))
        )

        let sellOperation = ClosureOperation<SubtensorTradeQuote> { [feeCalculator] in
            let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()
            let rate = try rateWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeSellQuote(
                from: quote,
                alpha: alpha,
                tolerance: tolerance,
                novaFee: feeCalculator.fee(basis: quote.sim.taoAmount, rate: rate)
            )
        }

        sellOperation.addDependency(quoteWrapper.targetOperation)
        sellOperation.addDependency(rateWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: sellOperation,
            dependencies: rateWrapper.allOperations + quoteWrapper.allOperations
        )
    }

    func ensureBeneficiary() throws {
        guard feeCalculator.beneficiary != nil else {
            throw SubtensorStakingOperationError.novaFeeUnavailable
        }
    }
}

extension SubtensorTradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol {
    func createTradeQuoteWrapper(
        for request: SubtensorTradeQuoteRequest
    ) -> CompoundOperationWrapper<SubtensorTradeQuote> {
        switch request {
        case let .buy(netuid, grossTao, tolerance):
            createBuyQuoteWrapper(netuid: netuid, grossTao: grossTao, tolerance: tolerance)
        case let .sell(netuid, alpha, tolerance):
            createSellQuoteWrapper(netuid: netuid, alpha: alpha, tolerance: tolerance)
        }
    }
}
