import Foundation

/// A route search that found nothing because every candidate path ran into a pool trade limit. It
/// replaces the plain "no route" answer with the number the user can actually trade, and — where the
/// violated hop is the one they typed into — an amount an action can apply directly.
///
/// It is raised only when the search would otherwise have returned `nil`. Where any candidate path
/// survives, the user gets their swap and never learns a limit was involved (§8).
struct AssetExchangeTradeLimitFailure: Error {
    /// The pool asset the cap is denominated in — the user's own asset whenever
    /// `isUserInputAdjustable`, an intermediate asset otherwise.
    let limitedAsset: ChainAsset

    /// The exact runtime threshold, undershot by nothing. Android's route message shows this value.
    let maxGivenAmount: Balance

    /// `MinTradingLimit`. A suggestion below it would be rejected on chain for a different reason, so
    /// there is no usable amount at all and nothing is suggested (FR-15).
    let minTradingLimit: Balance

    /// The direction the cap was measured in: a cap on the amount in for `.sell`, on the amount out
    /// for `.buy`.
    let direction: AssetConversion.Direction

    /// Whether the violated hop is the one quoted directly from the user's own amount — the first hop
    /// of a `.sell`, the last of a `.buy`. Only then can the suggestion be applied with one tap.
    let isUserInputAdjustable: Bool
}

extension AssetExchangeTradeLimitFailure {
    /// 5% below the cap, mirroring Android's `POOL_LIMIT_HEADROOM_SIZE`. The cap is computed from live
    /// reserves that drift between the tap, the re-validation and execution, and these pools are thin
    /// by definition, so the exact cap would re-trip the limit on any adverse move.
    static let headroom = BigRational.percent(of: 95)

    /// The amount to suggest, or `nil` when the pool admits no usable trade at all.
    ///
    /// The message and the tap-apply both read this one function, so the number shown and the number
    /// filled in cannot diverge — Android gets the same guarantee from a single local variable.
    func suggestion() -> Balance? {
        let headroomed = Self.headroom.mul(value: maxGivenAmount)

        let suggested = switch direction {
        case .sell:
            headroomed
        case .buy:
            // A `.buy` amount out is grossed up by the commission before it is re-quoted, so the raw
            // headroomed cap would come back to the pool as `1.0085 x` and trip the limit again. This
            // is the exact safe inverse of that gross-up. At the current 0.95 headroom the gross-up
            // could not re-trip on its own — 0.95 x 1.0085 < 1 — so what this really buys is an
            // explicit drift budget: the gross-up spends 0.85 of the 5 headroom points and leaves the
            // rest for reserve movement. It becomes load-bearing the moment the headroom rises above
            // 1 / 1.0085.
            grossUpInverse.mul(value: headroomed)
        }

        guard suggested >= minTradingLimit else {
            return nil
        }

        return suggested
    }

    private var grossUpInverse: BigRational {
        let rate = AssetExchangeCommissionConstants.rate

        return BigRational(
            numerator: rate.denominator,
            denominator: rate.denominator + rate.numerator
        )
    }
}
