import Foundation
import RobinHood
import BigInt
import SubstrateSdk
import HydraMath

final class HydraStableswapQuoteFactory {
    struct AssetReserveInfo: Codable {
        enum CodingKeys: String, CodingKey {
            case assetId = "asset_id"
            case amount
            case decimals
        }

        let assetId: UInt32
        @StringCodable var amount: BigUInt
        let decimals: UInt8
    }

    struct AssetAmount: Codable {
        enum CodingKeys: String, CodingKey {
            case assetId = "asset_id"
            case amount
        }

        let assetId: UInt32
        @StringCodable var amount: BigUInt
    }

    struct CalculationInfo {
        let poolInfo: HydraStableswap.PoolInfo
        let tradability: HydraStableswap.Tradability
        let shareAssetIssuance: BigUInt
        let reserves: [AssetReserveInfo]
        let currentBlock: BlockNumber
    }

    let flowState: HydraStableswapFlowState

    init(flowState: HydraStableswapFlowState) {
        self.flowState = flowState
    }

    private func deriveCalculationInfo(
        from quoteState: HydraStableswap.QuoteParams,
        with context: [CodingUserInfoKey: Any]?
    ) throws -> CalculationInfo {
        guard
            let poolInfo = quoteState.poolInfo.poolInfo,
            let tradability = quoteState.poolInfo.tradability,
            let currentBlock = quoteState.poolInfo.currentBlock else {
            throw CommonError.dataCorruption
        }

        let reserves: [AssetReserveInfo] = try poolInfo.assets.map { asset in
            let amount = try quoteState.reserves.getReserve(for: asset.value, with: context) ?? 0

            guard let decimals = try quoteState.reserves.getDecimals(for: asset.value, with: context) else {
                throw CommonError.dataCorruption
            }

            return AssetReserveInfo(
                assetId: UInt32(asset.value),
                amount: amount,
                decimals: decimals
            )
        }

        return CalculationInfo(
            poolInfo: poolInfo,
            tradability: tradability,
            shareAssetIssuance: try quoteState.reserves.getPoolTotalIssuance(with: context) ?? 0,
            reserves: reserves,
            currentBlock: currentBlock
        )
    }

    private func calculateAmplification(
        for poolInfo: HydraStableswap.PoolInfo,
        currentBlock: BlockNumber
    ) throws -> BigUInt {
        let amplificationResult = HydraStableswapMath.calculateAmplification(
            String(poolInfo.initialAmplification),
            String(poolInfo.finalAmplification),
            String(poolInfo.initialBlock),
            String(poolInfo.finalBlock),
            String(currentBlock)
        )

        guard let amplification = BigUInt(amplificationResult.toString()) else {
            throw AssetConversionOperationError.runtimeError("amplification calc failed")
        }

        return amplification
    }

    private func calculateOutGivenIn(
        for quoteState: HydraStableswap.QuoteParams,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId,
        amountIn: BigUInt,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> BigUInt {
        let calculationInfo = try deriveCalculationInfo(
            from: quoteState,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        )

        let amplification = try calculateAmplification(
            for: calculationInfo.poolInfo,
            currentBlock: calculationInfo.currentBlock
        )

        let fee = try BigRational.permillPercent(
            of: calculationInfo.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.calculateOutGivenIn(
            try JsonStringify.jsonString(from: calculationInfo.reserves),
            UInt32(assetIn),
            UInt32(assetOut),
            String(amountIn),
            String(amplification),
            fee
        )

        guard let amount = BigUInt(result.toString()) else {
            throw AssetConversionOperationError.runtimeError("out given in asset broken result")
        }

        return amount
    }

    private func calculateInGivenOut(
        for quoteState: HydraStableswap.QuoteParams,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId,
        amountOut: BigUInt,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> BigUInt {
        let calculationInfo = try deriveCalculationInfo(
            from: quoteState,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        )

        let amplification = try calculateAmplification(
            for: calculationInfo.poolInfo,
            currentBlock: calculationInfo.currentBlock
        )

        let fee = try BigRational.permillPercent(
            of: calculationInfo.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.calculateInGivenOut(
            try JsonStringify.jsonString(from: calculationInfo.reserves),
            UInt32(assetIn),
            UInt32(assetOut),
            String(amountOut),
            String(amplification),
            fee
        )

        guard let amount = BigUInt(result.toString()) else {
            throw AssetConversionOperationError.runtimeError("in given out asset broken result")
        }

        return amount
    }

    private func calculateAddOneAsset(
        for quoteState: HydraStableswap.QuoteParams,
        asset: HydraDx.AssetId,
        shareAmount: BigUInt,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> BigUInt {
        let calculationInfo = try deriveCalculationInfo(
            from: quoteState,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        )

        let amplification = try calculateAmplification(
            for: calculationInfo.poolInfo,
            currentBlock: calculationInfo.currentBlock
        )

        let fee = try BigRational.permillPercent(
            of: calculationInfo.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.calculateAddOneAsset(
            try JsonStringify.jsonString(from: calculationInfo.reserves),
            String(shareAmount),
            UInt32(asset),
            String(amplification),
            String(calculationInfo.shareAssetIssuance),
            fee
        )

        guard let amount = BigUInt(result.toString()) else {
            throw AssetConversionOperationError.runtimeError("add on asset broken result")
        }

        return amount
    }

    private func calculateLiquidityOutOneAsset(
        for quoteState: HydraStableswap.QuoteParams,
        asset: HydraDx.AssetId,
        shareAmount: BigUInt,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> BigUInt {
        let calculationInfo = try deriveCalculationInfo(
            from: quoteState,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        )

        let amplification = try calculateAmplification(
            for: calculationInfo.poolInfo,
            currentBlock: calculationInfo.currentBlock
        )

        let fee = try BigRational.permillPercent(
            of: calculationInfo.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.calculateLiquidityOutOneAsset(
            try JsonStringify.jsonString(from: calculationInfo.reserves),
            String(shareAmount),
            UInt32(asset),
            String(amplification),
            String(calculationInfo.shareAssetIssuance),
            fee
        )

        guard let amount = BigUInt(result.toString()) else {
            throw AssetConversionOperationError.runtimeError("liquidity out broken result")
        }

        return amount
    }

    private func calculateSharesForAmount(
        for quoteState: HydraStableswap.QuoteParams,
        asset: HydraDx.AssetId,
        assetAmount: BigUInt,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> BigUInt {
        let calculationInfo = try deriveCalculationInfo(
            from: quoteState,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        )

        let amplification = try calculateAmplification(
            for: calculationInfo.poolInfo,
            currentBlock: calculationInfo.currentBlock
        )

        let fee = try BigRational.permillPercent(
            of: calculationInfo.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.calculateSharesForAmount(
            try JsonStringify.jsonString(from: calculationInfo.reserves),
            UInt32(asset),
            String(assetAmount),
            String(amplification),
            String(calculationInfo.shareAssetIssuance),
            fee
        )

        guard let amount = BigUInt(result.toString()) else {
            throw AssetConversionOperationError.runtimeError("calculate shares broken result")
        }

        return amount
    }

    private func calculateShares(
        for quoteState: HydraStableswap.QuoteParams,
        asset: HydraDx.AssetId,
        assetAmount: BigUInt,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> BigUInt {
        let calculationInfo = try deriveCalculationInfo(
            from: quoteState,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        )

        let amplification = try calculateAmplification(
            for: calculationInfo.poolInfo,
            currentBlock: calculationInfo.currentBlock
        )

        let assets = [AssetAmount(assetId: UInt32(asset), amount: assetAmount)]

        let fee = try BigRational.permillPercent(
            of: calculationInfo.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.calculateShares(
            try JsonStringify.jsonString(from: calculationInfo.reserves),
            try JsonStringify.jsonString(from: assets),
            String(amplification),
            String(calculationInfo.shareAssetIssuance),
            fee
        )

        guard let amount = BigUInt(result.toString()) else {
            throw AssetConversionOperationError.runtimeError("calculate shares broken result")
        }

        return amount
    }

    private func calculateSellWhenAssetInPoolAsset(
        for params: HydraStableswap.QuoteParams,
        args: HydraStableswap.QuoteArgs,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraStableswap.Quote {
        let amount = try calculateLiquidityOutOneAsset(
            for: params,
            asset: args.assetOut,
            shareAmount: args.amount,
            codingFactory: codingFactory
        )

        return HydraStableswap.Quote(
            amountIn: args.amount,
            assetIn: args.assetIn,
            amountOut: amount,
            assetOut: args.assetOut
        )
    }

    private func calculateSellWhenAssetOutPoolAsset(
        for params: HydraStableswap.QuoteParams,
        args: HydraStableswap.QuoteArgs,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraStableswap.Quote {
        let amount = try calculateShares(
            for: params,
            asset: args.assetIn,
            assetAmount: args.amount,
            codingFactory: codingFactory
        )

        return HydraStableswap.Quote(
            amountIn: args.amount,
            assetIn: args.assetIn,
            amountOut: amount,
            assetOut: args.assetOut
        )
    }

    private func calculateBuyWhenAssetInPoolAsset(
        for params: HydraStableswap.QuoteParams,
        args: HydraStableswap.QuoteArgs,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraStableswap.Quote {
        let amount = try calculateSharesForAmount(
            for: params,
            asset: args.assetOut,
            assetAmount: args.amount,
            codingFactory: codingFactory
        )

        return HydraStableswap.Quote(
            amountIn: amount,
            assetIn: args.assetIn,
            amountOut: args.amount,
            assetOut: args.assetOut
        )
    }

    private func calculateBuyWhenAssetOutPoolAsset(
        for params: HydraStableswap.QuoteParams,
        args: HydraStableswap.QuoteArgs,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraStableswap.Quote {
        let amount = try calculateAddOneAsset(
            for: params,
            asset: args.assetIn,
            shareAmount: args.amount,
            codingFactory: codingFactory
        )

        return HydraStableswap.Quote(
            amountIn: amount,
            assetIn: args.assetIn,
            amountOut: args.amount,
            assetOut: args.assetOut
        )
    }

    private func calculateSellForNonPoolAssets(
        for params: HydraStableswap.QuoteParams,
        args: HydraStableswap.QuoteArgs,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraStableswap.Quote {
        let amount = try calculateOutGivenIn(
            for: params,
            assetIn: args.assetIn,
            assetOut: args.assetOut,
            amountIn: args.amount,
            codingFactory: codingFactory
        )

        return HydraStableswap.Quote(
            amountIn: args.amount,
            assetIn: args.assetIn,
            amountOut: amount,
            assetOut: args.assetOut
        )
    }

    private func calculateBuyForNonPoolAssets(
        for params: HydraStableswap.QuoteParams,
        args: HydraStableswap.QuoteArgs,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraStableswap.Quote {
        let amount = try calculateInGivenOut(
            for: params,
            assetIn: args.assetIn,
            assetOut: args.assetOut,
            amountOut: args.amount,
            codingFactory: codingFactory
        )

        return HydraStableswap.Quote(
            amountIn: amount,
            assetIn: args.assetIn,
            amountOut: args.amount,
            assetOut: args.assetOut
        )
    }

    private func calculateQuote(
        for quoteState: HydraStableswap.QuoteParams,
        args: HydraStableswap.QuoteArgs,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraStableswap.Quote {
        if args.assetIn == args.poolAsset {
            switch args.direction {
            case .sell:
                return try calculateSellWhenAssetInPoolAsset(
                    for: quoteState,
                    args: args,
                    codingFactory: codingFactory
                )
            case .buy:
                return try calculateBuyWhenAssetInPoolAsset(
                    for: quoteState,
                    args: args,
                    codingFactory: codingFactory
                )
            }
        } else if args.assetOut == args.poolAsset {
            switch args.direction {
            case .sell:
                return try calculateSellWhenAssetOutPoolAsset(
                    for: quoteState,
                    args: args,
                    codingFactory: codingFactory
                )
            case .buy:
                return try calculateBuyWhenAssetOutPoolAsset(
                    for: quoteState,
                    args: args,
                    codingFactory: codingFactory
                )
            }
        } else {
            switch args.direction {
            case .sell:
                return try calculateSellForNonPoolAssets(
                    for: quoteState,
                    args: args,
                    codingFactory: codingFactory
                )
            case .buy:
                return try calculateBuyForNonPoolAssets(
                    for: quoteState,
                    args: args,
                    codingFactory: codingFactory
                )
            }
        }
    }
}

extension HydraStableswapQuoteFactory {
    func quote(for args: HydraStableswap.QuoteArgs) -> CompoundOperationWrapper<HydraStableswap.Quote> {
        let poolPair = HydraStableswap.PoolPair(
            poolAsset: args.poolAsset,
            assetIn: args.assetIn,
            assetOut: args.assetOut
        )

        let quoteService = flowState.setupQuoteService(for: poolPair)

        let quoteStateOperation = quoteService.createFetchOperation()
        let codingFactoryOperation = flowState.runtimeProvider.fetchCoderFactoryOperation()

        let calculationOperation = ClosureOperation<HydraStableswap.Quote> {
            let params = try quoteStateOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return try self.calculateQuote(for: params, args: args, codingFactory: codingFactory)
        }

        calculationOperation.addDependency(quoteStateOperation)
        calculationOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: calculationOperation,
            dependencies: [quoteStateOperation, codingFactoryOperation]
        )
    }
}
