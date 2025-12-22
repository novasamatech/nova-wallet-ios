import Foundation
import HydraMathApi
import BigInt

enum HydraXYKSwapApiError: Error {
    case runtimeError(String)
}

enum HydraXYKSwapApi {
    static func calculateOutGivenIn(
        for balanceIn: BigUInt,
        balanceOut: BigUInt,
        amountIn: BigUInt
    ) throws -> BigUInt {
        let quoteResult = HydraXYKSwap.xykCalculateOutGivenIn(
            String(balanceIn),
            String(balanceOut),
            String(amountIn)
        )

        guard let quote = BigUInt(quoteResult.toString()) else {
            throw HydraXYKSwapApiError.runtimeError("given in calc out failed")
        }

        return quote
    }

    static func calculateInGivenOut(
        for balanceIn: BigUInt,
        balanceOut: BigUInt,
        amountOut: BigUInt
    ) throws -> BigUInt {
        let quoteResult = HydraXYKSwap.xykCalculateInGivenOut(
            String(balanceIn),
            String(balanceOut),
            String(amountOut)
        )

        guard let quote = BigUInt(quoteResult.toString()) else {
            throw HydraXYKSwapApiError.runtimeError("given out calc in failed")
        }

        return quote
    }

    static func calculaPoolFee(
        for amount: BigUInt,
        feeNominator: UInt32,
        feeDenominator: UInt32
    ) throws -> BigUInt {
        let feeResult = HydraXYKSwap.xykCalculatePoolTradeFee(
            String(amount),
            String(feeNominator),
            String(feeDenominator)
        )

        guard let fee = BigUInt(feeResult.toString()) else {
            throw HydraXYKSwapApiError.runtimeError("pool fee failed")
        }

        return fee
    }
}
