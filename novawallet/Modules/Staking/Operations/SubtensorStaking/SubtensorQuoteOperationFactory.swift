import BigInt
import Foundation
import Operation_iOS

struct SubtensorQuoteArgs: Equatable {
    enum Direction: Equatable {
        case stake(taoIn: Balance)
        case unstake(alphaIn: Balance)
    }

    let netuid: UInt16
    let direction: Direction
}

enum SubtensorQuoteError: Error, Equatable {
    case missingSpotPrice(netuid: UInt16)
    case quoteUnavailable(netuid: UInt16)
}

struct SubtensorQuote: Equatable {
    let args: SubtensorQuoteArgs
    let sim: SubtensorStakingPallet.SimSwapResult
    let spotPrice: Balance
    let feeRate: UInt16
    let capturedAt: Date

    init(
        args: SubtensorQuoteArgs,
        sim: SubtensorStakingPallet.SimSwapResult,
        spotPrice: Balance,
        feeRate: UInt16,
        capturedAt: Date = Date()
    ) {
        self.args = args
        self.sim = sim
        self.spotPrice = spotPrice
        self.feeRate = feeRate
        self.capturedAt = capturedAt
    }
}

extension SubtensorQuote {
    var expectedOut: Balance {
        switch args.direction {
        case .stake:
            return sim.alphaAmount
        case .unstake:
            return sim.taoAmount
        }
    }

    var poolFee: Balance {
        switch args.direction {
        case .stake:
            return sim.taoFee
        case .unstake:
            return sim.alphaFee
        }
    }

    /// pool-move component only: the sim amounts are net of the input-side fee, so the fee
    /// never double-counts into the impact
    var priceImpact: BigRational? {
        guard let postTradePrice else {
            return nil
        }

        let move = postTradePrice > spotPrice ? postTradePrice - spotPrice : spotPrice - postTradePrice

        return BigRational(numerator: move, denominator: spotPrice)
    }

    var postTradePrice: Balance? {
        guard sim.alphaAmount > 0, spotPrice > 0 else {
            return nil
        }

        let scaledTao = sim.taoAmount * SubtensorStakingPallet.alphaPriceScale

        switch args.direction {
        case .stake:
            let averagePrice = Self.divideRoundingUp(scaledTao, by: sim.alphaAmount)

            return Self.divideRoundingUp(averagePrice * averagePrice, by: spotPrice)
        case .unstake:
            let averagePrice = scaledTao / sim.alphaAmount

            return averagePrice * averagePrice / spotPrice
        }
    }
}

private extension SubtensorQuote {
    static func divideRoundingUp(_ dividend: Balance, by divisor: Balance) -> Balance {
        (dividend + divisor - 1) / divisor
    }
}

protocol SubtensorQuoteOperationFactoryProtocol {
    func createQuoteWrapper(for args: SubtensorQuoteArgs) -> CompoundOperationWrapper<SubtensorQuote>
}

final class SubtensorQuoteOperationFactory {
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        operationFactory: SubtensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }
}

private extension SubtensorQuoteOperationFactory {
    static func ensureExecutable(
        _ sim: SubtensorStakingPallet.SimSwapResult,
        for args: SubtensorQuoteArgs
    ) throws {
        // engine failures collapse to zero amounts at the runtime api boundary while the
        // slippage fields can stay populated, so the zero OUT amount is the only sentinel
        let expectedOut: Balance

        switch args.direction {
        case .stake:
            expectedOut = sim.alphaAmount
        case .unstake:
            expectedOut = sim.taoAmount
        }

        guard expectedOut > 0 else {
            throw SubtensorQuoteError.quoteUnavailable(netuid: args.netuid)
        }
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

            try Self.ensureExecutable(sim, for: args)

            return SubtensorQuote(
                args: args,
                sim: sim,
                spotPrice: spotPrice,
                feeRate: feeRate
            )
        }

        mergeOperation.addDependency(simWrapper.targetOperation)
        mergeOperation.addDependency(priceWrapper.targetOperation)
        mergeOperation.addDependency(feeRateWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: simWrapper.allOperations + priceWrapper.allOperations + feeRateWrapper.allOperations
        )
    }
}

extension SubtensorQuoteOperationFactory: SubtensorQuoteOperationFactoryProtocol {
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
}
