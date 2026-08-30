import Foundation
import BigInt
import Operation_iOS
import SubstrateSdk

enum HydraExchangeTradeLimitError: Error {
    /// A ratio constant is absent from runtime metadata. The pool cannot be validated, so the swap
    /// cannot proceed (FR-6).
    case ratiosUnavailable(pallet: String)

    /// A ratio decoded as zero.
    case ratioUnusable
}

/// Mirrors the `MaxInRatio` / `MaxOutRatio` checks the XYK and Omnipool pallets run inside
/// `validate_sell` / `validate_buy` and `sell` / `buy` respectively. The router does not perform them,
/// so a quote that ignores them produces an extrinsic the chain reverts.
enum HydraExchangeTradeLimits {
    /// The per-trade limits of one pallet. Absence of a ratio is handled upstream by failing the quote,
    /// so the ratios never encode "unlimited". `minTradingLimit` is different: it gates only the
    /// suggested amount, never the quote, so it is optional.
    struct PoolLimits: Equatable {
        let maxInRatio: Balance
        let maxOutRatio: Balance
        let minTradingLimit: Balance?
    }

    /// `reserve / ratio` with integer floor division, matching the pallet. Throws rather than trapping
    /// on a zero ratio.
    static func bound(reserve: Balance, ratio: Balance) throws -> Balance {
        guard ratio > 0 else {
            throw HydraExchangeTradeLimitError.ratioUnusable
        }

        return reserve / ratio
    }

    /// `validate_sell`: the amount in against `MaxInRatio`, and the **pre-fee** amount out against
    /// `MaxOutRatio`. The pallet's `ensure!` sits between the math call and `calculate_fee`, so the
    /// post-fee quote is never the checked quantity (FR-2).
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

    /// `validate_buy`: the amount out against `MaxOutRatio`, and the **pre-fee** amount in against
    /// `MaxInRatio`.
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

    /// Omnipool checks the quoted amounts directly: its `MaxOutRatio` check runs before
    /// `account_for_fee_taken`, which never touches `delta_reserve` (FR-3).
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
    /// The largest amount in `validate_sell` accepts, derived from its two `ensure!`s: the direct bound
    /// `R_in / MaxInRatio`, and the largest amount whose pre-fee output stays within `R_out / MaxOutRatio`.
    ///
    /// The second is `ceil((maxOutAmount + 1) * R_in / (R_out - maxOutAmount - 1)) - 1`, written as
    /// `(n - 1) / d` because `ceil(n/d) - 1 == (n - 1) / d` for `n >= 1` and the `- 1` would otherwise
    /// underflow in `Balance`. Zero reserves are rejected outright by the pallet, and a `R_out` at or
    /// below `maxOutAmount + 1` makes the out side vacuous — both are guarded rather than divided by.
    ///
    /// At the mainnet 3/3 constants the out side never binds, but FR-4 reads the ratios per pallet from
    /// metadata and permits them to diverge, so both terms are kept.
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

    /// The largest amount out `validate_buy` accepts: the direct bound `R_out / MaxOutRatio`, and the
    /// largest amount whose pre-fee input stays within `R_in / MaxInRatio`.
    ///
    /// The second is `ceil(maxInAmount * R_out / (R_in + maxInAmount)) - 1`. The `ceil` is not
    /// decoration: `calculate_in_given_out` ends in `round_up!`, an unconditional `+ 1`, so the plain
    /// `floor` form over-reports by exactly one raw unit in roughly one pool in twelve. A `maxInAmount`
    /// of zero admits no trade at all, because the rounded-up price is at least 1 for every amount.
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

    /// Only the bound on the *given* amount is closed-form in Omnipool — it is the pallet's own
    /// predicate, so it is tight rather than approximate. The bound on the derived amount runs through
    /// the pool math and has no inverse, so it is checked with a single probe at the direct bound and
    /// the cap is abandoned when the probe fails. Bisecting instead would cost tens of FFI round trips
    /// per candidate path, and §4's slip-fee caveat makes any Omnipool cap best-effort regardless.
    ///
    /// `nil` is an ordinary outcome, not an error: the rejection still prunes the candidate, it just
    /// carries no number to report.
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
    /// The per-trade limit constants of a single pallet. Each pool type owns its own set and never
    /// borrows the other's, so the paths travel with the name reported when one is absent.
    struct PalletLimitConstants {
        let pallet: String
        let maxInRatioPath: ConstantCodingPath
        let maxOutRatioPath: ConstantCodingPath
        let minTradingLimitPath: ConstantCodingPath

        static let xyk = PalletLimitConstants(
            pallet: HydraXYK.name,
            maxInRatioPath: HydraXYK.maxInRatioPath,
            maxOutRatioPath: HydraXYK.maxOutRatioPath,
            minTradingLimitPath: HydraXYK.minTradingLimitPath
        )

        static let omnipool = PalletLimitConstants(
            pallet: HydraOmnipool.moduleName,
            maxInRatioPath: HydraOmnipool.maxInRatioPath,
            maxOutRatioPath: HydraOmnipool.maxOutRatioPath,
            minTradingLimitPath: HydraOmnipool.minTradingLimitPath
        )
    }

    /// Fetches one pallet's limits. The two ratios have no fallback, so a ratio missing from metadata
    /// fails the quote instead of being read as "unlimited" (FR-5).
    ///
    /// `MinTradingLimit` is deliberately not fail-closed: it gates only the suggested amount, never the
    /// validity of a trade, so its absence yields `nil` and suppresses the suggestion. Failing every
    /// Hydration quote because a suggestion-only constant was renamed would be out of all proportion.
    static func createPoolLimitsWrapper(
        for constants: PalletLimitConstants,
        dependingOn coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<PoolLimits> {
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

        let mergeOperation = ClosureOperation<PoolLimits> {
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
                throw HydraExchangeTradeLimitError.ratiosUnavailable(pallet: constants.pallet)
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
