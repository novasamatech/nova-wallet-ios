import Foundation
import BigInt
import Operation_iOS
import SubstrateSdk

enum HydraExchangeTradeLimitError: Error {
    case ratioUnusable
}

enum HydraExchangeTradeLimits {
    struct PoolLimits: Equatable {
        let maxInRatio: Balance
        let maxOutRatio: Balance
        let minTradingLimit: Balance?
    }

    static func bound(reserve: Balance, ratio: Balance) throws -> Balance {
        guard ratio > 0 else {
            throw HydraExchangeTradeLimitError.ratioUnusable
        }

        return reserve / ratio
    }

    static func xykSellExceedsLimit(
        amountIn: Balance,
        amountOutPreFee: Balance,
        reserveIn: Balance,
        reserveOut: Balance,
        limits: PoolLimits
    ) throws -> Bool {
        try exceeds(amount: amountIn, reserve: reserveIn, ratio: limits.maxInRatio)
            || (try exceeds(amount: amountOutPreFee, reserve: reserveOut, ratio: limits.maxOutRatio))
    }

    static func xykBuyExceedsLimit(
        amountOut: Balance,
        amountInPreFee: Balance,
        reserveIn: Balance,
        reserveOut: Balance,
        limits: PoolLimits
    ) throws -> Bool {
        try exceeds(amount: amountOut, reserve: reserveOut, ratio: limits.maxOutRatio)
            || (try exceeds(amount: amountInPreFee, reserve: reserveIn, ratio: limits.maxInRatio))
    }

    static func omnipoolExceedsLimit(
        amountIn: Balance,
        amountOut: Balance,
        reserveIn: Balance,
        reserveOut: Balance,
        limits: PoolLimits
    ) throws -> Bool {
        try exceeds(amount: amountIn, reserve: reserveIn, ratio: limits.maxInRatio)
            || (try exceeds(amount: amountOut, reserve: reserveOut, ratio: limits.maxOutRatio))
    }
}

// MARK: - Cap arithmetic

extension HydraExchangeTradeLimits {
    static func maxSellAmountIn(
        reserveIn: Balance,
        reserveOut: Balance,
        limits: PoolLimits
    ) throws -> Balance {
        guard reserveIn > 0, reserveOut > 0 else {
            return 0
        }

        let maxInAmount = try bound(reserve: reserveIn, ratio: limits.maxInRatio)
        let maxOutAmount = try bound(reserve: reserveOut, ratio: limits.maxOutRatio)

        guard reserveOut > maxOutAmount + 1 else {
            return maxInAmount
        }

        let numerator = (maxOutAmount + 1) * reserveIn

        return min(maxInAmount, (numerator - 1) / (reserveOut - maxOutAmount - 1))
    }

    static func maxBuyAmountOut(
        reserveIn: Balance,
        reserveOut: Balance,
        limits: PoolLimits
    ) throws -> Balance {
        guard reserveIn > 0, reserveOut > 0 else {
            return 0
        }

        let maxOutAmount = try bound(reserve: reserveOut, ratio: limits.maxOutRatio)
        let maxInAmount = try bound(reserve: reserveIn, ratio: limits.maxInRatio)

        guard maxInAmount > 0 else {
            return 0
        }

        let numerator = maxInAmount * reserveOut

        return min(maxOutAmount, (numerator - 1) / (reserveIn + maxInAmount))
    }

    static func omnipoolCap(
        direction: AssetConversion.Direction,
        params: HydraOmnipoolApi.Params,
        limits: PoolLimits
    ) throws -> Balance? {
        switch direction {
        case .sell:
            let directBound = try bound(reserve: params.assetInBalance, ratio: limits.maxInRatio)
            let derivedBound = try bound(reserve: params.assetOutBalance, ratio: limits.maxOutRatio)

            guard directBound > 0 else {
                return nil
            }

            do {
                let probe = try HydraOmnipoolApi.calculateOutGivenIn(for: params, amountIn: directBound)

                return probe <= derivedBound ? directBound : nil
            } catch HydraOmnipoolApiError.runtimeError {
                return nil
            }
        case .buy:
            let directBound = try bound(reserve: params.assetOutBalance, ratio: limits.maxOutRatio)
            let derivedBound = try bound(reserve: params.assetInBalance, ratio: limits.maxInRatio)

            guard directBound > 0 else {
                return nil
            }

            do {
                let probe = try HydraOmnipoolApi.calculateInGivenOut(for: params, amountOut: directBound)

                return probe <= derivedBound ? directBound : nil
            } catch HydraOmnipoolApiError.runtimeError {
                return nil
            }
        }
    }
}

private extension HydraExchangeTradeLimits {
    static func exceeds(amount: Balance, reserve: Balance, ratio: Balance) throws -> Bool {
        let maxAmount = try bound(reserve: reserve, ratio: ratio)

        return amount > maxAmount
    }
}

// MARK: - Constants

extension HydraExchangeTradeLimits {
    struct PalletLimitConstants {
        let maxInRatioPath: ConstantCodingPath
        let maxOutRatioPath: ConstantCodingPath
        let minTradingLimitPath: ConstantCodingPath

        static let xyk = PalletLimitConstants(
            maxInRatioPath: HydraXYK.maxInRatioPath,
            maxOutRatioPath: HydraXYK.maxOutRatioPath,
            minTradingLimitPath: HydraXYK.minTradingLimitPath
        )

        static let omnipool = PalletLimitConstants(
            maxInRatioPath: HydraOmnipool.maxInRatioPath,
            maxOutRatioPath: HydraOmnipool.maxOutRatioPath,
            minTradingLimitPath: HydraOmnipool.minTradingLimitPath
        )
    }

    static func createPoolLimitsWrapper(
        for constants: PalletLimitConstants,
        dependingOn coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<PoolLimits?> {
        let maxInRatioOperation: BaseOperation<Balance> = PrimitiveConstantOperation.operation(
            for: constants.maxInRatioPath,
            dependingOn: coderFactoryOperation
        )

        maxInRatioOperation.addDependency(coderFactoryOperation)

        let maxOutRatioOperation: BaseOperation<Balance> = PrimitiveConstantOperation.operation(
            for: constants.maxOutRatioPath,
            dependingOn: coderFactoryOperation
        )

        maxOutRatioOperation.addDependency(coderFactoryOperation)

        let minTradingLimitOperation: BaseOperation<Balance> = PrimitiveConstantOperation.operation(
            for: constants.minTradingLimitPath,
            dependingOn: coderFactoryOperation
        )

        minTradingLimitOperation.addDependency(coderFactoryOperation)

        let mergeOperation = ClosureOperation<PoolLimits?> {
            let minTradingLimit: Balance?

            do {
                minTradingLimit = try minTradingLimitOperation.extractNoCancellableResultData()
            } catch let error as StorageDecodingOperationError where error == .invalidStoragePath {
                minTradingLimit = nil
            }

            do {
                let maxInRatio = try maxInRatioOperation.extractNoCancellableResultData()
                let maxOutRatio = try maxOutRatioOperation.extractNoCancellableResultData()

                return PoolLimits(
                    maxInRatio: maxInRatio,
                    maxOutRatio: maxOutRatio,
                    minTradingLimit: minTradingLimit
                )
            } catch let error as StorageDecodingOperationError where error == .invalidStoragePath {
                return nil
            }
        }

        mergeOperation.addDependency(maxInRatioOperation)
        mergeOperation.addDependency(maxOutRatioOperation)
        mergeOperation.addDependency(minTradingLimitOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [maxInRatioOperation, maxOutRatioOperation, minTradingLimitOperation]
        )
    }
}
