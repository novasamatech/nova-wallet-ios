import Foundation
import SubstrateSdk
import HydraMath
import BigInt

enum HydraStableswapApiError: Error {
    case runtimeError(String)
}

enum HydraStableswapApi {
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

    struct Params {
        let poolInfo: HydraStableswap.PoolInfo
        let tradability: HydraStableswap.Tradability?
        let shareAssetIssuance: BigUInt
        let reserves: [AssetReserveInfo]
        let currentBlock: BlockNumber
        let pegs: [[StringCodable<BigUInt>]]
    }

    static func calculateAmplification(
        for poolInfo: HydraStableswap.PoolInfo,
        currentBlock: BlockNumber
    ) throws -> BigUInt {
        let amplificationResult = HydraStableswapMath.stableswapCalculateAmplification(
            String(poolInfo.initialAmplification),
            String(poolInfo.finalAmplification),
            String(poolInfo.initialBlock),
            String(poolInfo.finalBlock),
            String(currentBlock)
        )

        guard let amplification = BigUInt(amplificationResult.toString()) else {
            throw HydraStableswapApiError.runtimeError("amplification calc failed")
        }

        return amplification
    }

    static func calculateOutGivenIn(
        for params: Params,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId,
        amountIn: BigUInt
    ) throws -> BigUInt {
        let amplification = try calculateAmplification(
            for: params.poolInfo,
            currentBlock: params.currentBlock
        )

        let fee = try BigRational.permillPercent(
            of: params.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.stableswapCalculateOutGivenIn(
            try JsonStringify.jsonString(from: params.reserves),
            UInt32(assetIn),
            UInt32(assetOut),
            String(amountIn),
            String(amplification),
            fee,
            try JsonStringify.jsonString(from: params.pegs)
        )

        guard let amount = BigUInt(result.toString()) else {
            throw HydraStableswapApiError.runtimeError("out given in asset broken result")
        }

        return amount
    }

    static func calculateInGivenOut(
        for params: Params,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId,
        amountOut: BigUInt
    ) throws -> BigUInt {
        let amplification = try calculateAmplification(
            for: params.poolInfo,
            currentBlock: params.currentBlock
        )

        let fee = try BigRational.permillPercent(
            of: params.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.stableswapCalculateInGivenOut(
            try JsonStringify.jsonString(from: params.reserves),
            UInt32(assetIn),
            UInt32(assetOut),
            String(amountOut),
            String(amplification),
            fee,
            try JsonStringify.jsonString(from: params.pegs)
        )

        guard let amount = BigUInt(result.toString()) else {
            throw HydraStableswapApiError.runtimeError("in given out asset broken result")
        }

        return amount
    }

    static func calculateAddOneAsset(
        for params: Params,
        asset: HydraDx.AssetId,
        shareAmount: BigUInt
    ) throws -> BigUInt {
        let amplification = try calculateAmplification(
            for: params.poolInfo,
            currentBlock: params.currentBlock
        )

        let fee = try BigRational.permillPercent(
            of: params.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.stableswapCalculateAddOneAsset(
            try JsonStringify.jsonString(from: params.reserves),
            String(shareAmount),
            UInt32(asset),
            String(amplification),
            String(params.shareAssetIssuance),
            fee,
            try JsonStringify.jsonString(from: params.pegs)
        )

        guard let amount = BigUInt(result.toString()) else {
            throw HydraStableswapApiError.runtimeError("add on asset broken result")
        }

        return amount
    }

    static func calculateLiquidityOutOneAsset(
        for params: Params,
        asset: HydraDx.AssetId,
        shareAmount: BigUInt
    ) throws -> BigUInt {
        let amplification = try calculateAmplification(
            for: params.poolInfo,
            currentBlock: params.currentBlock
        )

        let fee = try BigRational.permillPercent(
            of: params.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.stableswapCalculateLiquidityOutOneAsset(
            try JsonStringify.jsonString(from: params.reserves),
            String(shareAmount),
            UInt32(asset),
            String(amplification),
            String(params.shareAssetIssuance),
            fee,
            try JsonStringify.jsonString(from: params.pegs)
        )

        guard let amount = BigUInt(result.toString()) else {
            throw HydraStableswapApiError.runtimeError("liquidity out broken result")
        }

        return amount
    }

    static func calculateSharesForAmount(
        for params: Params,
        asset: HydraDx.AssetId,
        assetAmount: BigUInt
    ) throws -> BigUInt {
        let amplification = try calculateAmplification(
            for: params.poolInfo,
            currentBlock: params.currentBlock
        )

        let fee = try BigRational.permillPercent(
            of: params.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.stableswapCalculateSharesForAmount(
            try JsonStringify.jsonString(from: params.reserves),
            UInt32(asset),
            String(assetAmount),
            String(amplification),
            String(params.shareAssetIssuance),
            fee,
            try JsonStringify.jsonString(from: params.pegs)
        )

        guard let amount = BigUInt(result.toString()) else {
            throw HydraStableswapApiError.runtimeError("calculate shares broken result")
        }

        return amount
    }

    static func calculateShares(
        for params: Params,
        asset: HydraDx.AssetId,
        assetAmount: BigUInt
    ) throws -> BigUInt {
        let amplification = try calculateAmplification(
            for: params.poolInfo,
            currentBlock: params.currentBlock
        )

        let assets = [AssetAmount(assetId: UInt32(asset), amount: assetAmount)]

        let fee = try BigRational.permillPercent(
            of: params.poolInfo.fee
        ).decimalOrError().stringWithPointSeparator

        let result = HydraStableswapMath.stableswapCalculateShares(
            try JsonStringify.jsonString(from: params.reserves),
            try JsonStringify.jsonString(from: assets),
            String(amplification),
            String(params.shareAssetIssuance),
            fee,
            try JsonStringify.jsonString(from: params.pegs)
        )

        guard let amount = BigUInt(result.toString()) else {
            throw HydraStableswapApiError.runtimeError("calculate shares broken result")
        }

        return amount
    }
}
