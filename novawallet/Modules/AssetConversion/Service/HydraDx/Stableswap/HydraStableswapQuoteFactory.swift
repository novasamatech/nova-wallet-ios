import Foundation
import RobinHood
import BigInt
import SubstrateSdk
import HydraMath

final class HydraStableswapQuoteFactory {
    let flowState: HydraStableswapFlowState

    init(flowState: HydraStableswapFlowState) {
        self.flowState = flowState
    }

    private func deriveApiParams(
        from quoteState: HydraStableswap.QuoteParams,
        with context: [CodingUserInfoKey: Any]?
    ) throws -> HydraStableswapApi.Params {
        guard
            let poolInfo = quoteState.poolInfo.poolInfo,
            let currentBlock = quoteState.poolInfo.currentBlock else {
            throw CommonError.dataCorruption
        }

        let reserves: [HydraStableswapApi.AssetReserveInfo] = try poolInfo.assets.map { asset in
            let amount = try quoteState.reserves.getReserve(for: asset.value, with: context) ?? 0

            guard let decimals = try quoteState.reserves.getDecimals(for: asset.value, with: context) else {
                throw CommonError.dataCorruption
            }

            return HydraStableswapApi.AssetReserveInfo(
                assetId: UInt32(asset.value),
                amount: amount,
                decimals: decimals
            )
        }

        return .init(
            poolInfo: poolInfo,
            tradability: quoteState.poolInfo.tradability,
            shareAssetIssuance: try quoteState.reserves.getPoolTotalIssuance(with: context) ?? 0,
            reserves: reserves,
            currentBlock: currentBlock
        )
    }

    private func calculateSellWhenAssetInPoolAsset(
        for apiParams: HydraStableswapApi.Params,
        args: HydraStableswap.QuoteArgs
    ) throws -> BigUInt {
        if let tradeability = apiParams.tradability, !tradeability.canRemoveLiquidity() {
            throw AssetConversionOperationError.quoteCalcFailed
        }

        return try HydraStableswapApi.calculateLiquidityOutOneAsset(
            for: apiParams,
            asset: args.assetOut,
            shareAmount: args.amount
        )
    }

    private func calculateSellWhenAssetOutPoolAsset(
        for apiParams: HydraStableswapApi.Params,
        args: HydraStableswap.QuoteArgs
    ) throws -> BigUInt {
        if let tradeability = apiParams.tradability, !tradeability.canAddLiquidity() {
            throw AssetConversionOperationError.quoteCalcFailed
        }

        return try HydraStableswapApi.calculateShares(
            for: apiParams,
            asset: args.assetIn,
            assetAmount: args.amount
        )
    }

    private func calculateBuyWhenAssetInPoolAsset(
        for apiParams: HydraStableswapApi.Params,
        args: HydraStableswap.QuoteArgs
    ) throws -> BigUInt {
        if let tradeability = apiParams.tradability, !tradeability.canRemoveLiquidity() {
            throw AssetConversionOperationError.quoteCalcFailed
        }

        return try HydraStableswapApi.calculateSharesForAmount(
            for: apiParams,
            asset: args.assetOut,
            assetAmount: args.amount
        )
    }

    private func calculateBuyWhenAssetOutPoolAsset(
        for apiParams: HydraStableswapApi.Params,
        args: HydraStableswap.QuoteArgs
    ) throws -> BigUInt {
        // no checks for tradeability in runtime, added for safety

        try HydraStableswapApi.calculateAddOneAsset(
            for: apiParams,
            asset: args.assetIn,
            shareAmount: args.amount
        )
    }

    private func calculateSellForNonPoolAssets(
        for apiParams: HydraStableswapApi.Params,
        args: HydraStableswap.QuoteArgs
    ) throws -> BigUInt {
        if let tradeability = apiParams.tradability, !tradeability.canSell() {
            throw AssetConversionOperationError.quoteCalcFailed
        }

        return try HydraStableswapApi.calculateOutGivenIn(
            for: apiParams,
            assetIn: args.assetIn,
            assetOut: args.assetOut,
            amountIn: args.amount
        )
    }

    private func calculateBuyForNonPoolAssets(
        for apiParams: HydraStableswapApi.Params,
        args: HydraStableswap.QuoteArgs
    ) throws -> BigUInt {
        if let tradeability = apiParams.tradability, !tradeability.canBuy() {
            throw AssetConversionOperationError.quoteCalcFailed
        }

        return try HydraStableswapApi.calculateInGivenOut(
            for: apiParams,
            assetIn: args.assetIn,
            assetOut: args.assetOut,
            amountOut: args.amount
        )
    }

    private func calculateQuote(
        for apiParams: HydraStableswapApi.Params,
        args: HydraStableswap.QuoteArgs
    ) throws -> BigUInt {
        if args.assetIn == args.poolAsset {
            switch args.direction {
            case .sell:
                return try calculateSellWhenAssetInPoolAsset(
                    for: apiParams,
                    args: args
                )
            case .buy:
                return try calculateBuyWhenAssetInPoolAsset(
                    for: apiParams,
                    args: args
                )
            }
        } else if args.assetOut == args.poolAsset {
            switch args.direction {
            case .sell:
                return try calculateSellWhenAssetOutPoolAsset(
                    for: apiParams,
                    args: args
                )
            case .buy:
                return try calculateBuyWhenAssetOutPoolAsset(
                    for: apiParams,
                    args: args
                )
            }
        } else {
            switch args.direction {
            case .sell:
                return try calculateSellForNonPoolAssets(
                    for: apiParams,
                    args: args
                )
            case .buy:
                return try calculateBuyForNonPoolAssets(
                    for: apiParams,
                    args: args
                )
            }
        }
    }
}

extension HydraStableswapQuoteFactory {
    func quote(for args: HydraStableswap.QuoteArgs) -> CompoundOperationWrapper<BigUInt> {
        let poolPair = HydraStableswap.PoolPair(
            poolAsset: args.poolAsset,
            assetIn: args.assetIn,
            assetOut: args.assetOut
        )

        let quoteService = flowState.setupQuoteService(for: poolPair)

        let quoteStateOperation = quoteService.createFetchOperation()
        let codingFactoryOperation = flowState.runtimeProvider.fetchCoderFactoryOperation()

        let calculationOperation = ClosureOperation<BigUInt> {
            let quoteState = try quoteStateOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let apiParams = try self.deriveApiParams(
                from: quoteState,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )

            return try self.calculateQuote(for: apiParams, args: args)
        }

        calculationOperation.addDependency(quoteStateOperation)
        calculationOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: calculationOperation,
            dependencies: [quoteStateOperation, codingFactoryOperation]
        )
    }
}
