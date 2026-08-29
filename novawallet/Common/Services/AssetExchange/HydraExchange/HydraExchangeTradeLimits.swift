import Foundation
import BigInt
import Operation_iOS
import SubstrateSdk

enum HydraExchangeTradeLimitError: Error {
    /// The trade exceeds one of the pool's per-trade ratio bounds.
    case exceedsPoolTradeLimit

    /// A ratio constant is absent from runtime metadata.
    /// The pool cannot be validated, so it cannot be quoted.
    case ratiosUnavailable(pallet: String)

    /// A ratio decoded as zero.
    case ratioUnusable
}

/// Mirrors the `MaxInRatio` / `MaxOutRatio` checks the XYK and Omnipool pallets run inside
/// `validate_sell` / `validate_buy` and `sell` / `buy` respectively. The router does not perform them,
/// so a quote that ignores them produces an extrinsic the chain reverts.
enum HydraExchangeTradeLimits {
    /// Decoded `MaxInRatio` / `MaxOutRatio` for one pallet. Absence is handled upstream by failing the
    /// quote, so this type never encodes "unlimited".
    struct Ratios: Equatable {
        let maxInRatio: Balance
        let maxOutRatio: Balance
    }

    /// `reserve / ratio` with integer floor division, matching the pallet. Throws rather than trapping
    /// on a zero ratio.
    static func bound(reserve: Balance, ratio: Balance) throws -> Balance {
        guard ratio > 0 else {
            throw HydraExchangeTradeLimitError.ratioUnusable
        }

        return reserve / ratio
    }

    static func validateXYKSell(
        amountIn: Balance,
        amountOutPreFee: Balance,
        reserveIn: Balance,
        reserveOut: Balance,
        ratios: Ratios
    ) throws {
        try validate(amount: amountIn, reserve: reserveIn, ratio: ratios.maxInRatio)
        try validate(amount: amountOutPreFee, reserve: reserveOut, ratio: ratios.maxOutRatio)
    }

    static func validateXYKBuy(
        amountOut: Balance,
        amountInPreFee: Balance,
        reserveIn: Balance,
        reserveOut: Balance,
        ratios: Ratios
    ) throws {
        try validate(amount: amountOut, reserve: reserveOut, ratio: ratios.maxOutRatio)
        try validate(amount: amountInPreFee, reserve: reserveIn, ratio: ratios.maxInRatio)
    }

    static func validateOmnipool(
        amountIn: Balance,
        amountOut: Balance,
        reserveIn: Balance,
        reserveOut: Balance,
        ratios: Ratios
    ) throws {
        try validate(amount: amountIn, reserve: reserveIn, ratio: ratios.maxInRatio)
        try validate(amount: amountOut, reserve: reserveOut, ratio: ratios.maxOutRatio)
    }
}

private extension HydraExchangeTradeLimits {
    static func validate(amount: Balance, reserve: Balance, ratio: Balance) throws {
        let maxAmount = try bound(reserve: reserve, ratio: ratio)

        guard amount <= maxAmount else {
            throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit
        }
    }
}

extension HydraExchangeTradeLimits {
    /// The `MaxInRatio` / `MaxOutRatio` pair of a single pallet. Each pool type owns its own pair and
    /// never borrows the other's, so the paths travel with the name reported when one is absent.
    struct RatioConstants {
        let pallet: String
        let maxInRatioPath: ConstantCodingPath
        let maxOutRatioPath: ConstantCodingPath

        static let xyk = RatioConstants(
            pallet: HydraXYK.name,
            maxInRatioPath: HydraXYK.maxInRatioPath,
            maxOutRatioPath: HydraXYK.maxOutRatioPath
        )

        static let omnipool = RatioConstants(
            pallet: HydraOmnipool.moduleName,
            maxInRatioPath: HydraOmnipool.maxInRatioPath,
            maxOutRatioPath: HydraOmnipool.maxOutRatioPath
        )
    }

    /// Fetches both ratios of one pallet with no fallback value, so a constant missing from metadata
    /// fails the quote instead of being read as "unlimited".
    static func createRatiosWrapper(
        for constants: RatioConstants,
        dependingOn coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<Ratios> {
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

        let mergeOperation = ClosureOperation<Ratios> {
            do {
                let maxInRatio = try maxInRatioOperation.extractNoCancellableResultData()
                let maxOutRatio = try maxOutRatioOperation.extractNoCancellableResultData()

                return Ratios(maxInRatio: maxInRatio, maxOutRatio: maxOutRatio)
            } catch let error as StorageDecodingOperationError where error == .invalidStoragePath {
                throw HydraExchangeTradeLimitError.ratiosUnavailable(pallet: constants.pallet)
            }
        }

        mergeOperation.addDependency(maxInRatioOperation)
        mergeOperation.addDependency(maxOutRatioOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [maxInRatioOperation, maxOutRatioOperation]
        )
    }
}
