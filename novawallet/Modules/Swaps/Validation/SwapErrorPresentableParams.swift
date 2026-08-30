import Foundation

enum SwapDisplayError {
    struct InsufficientBalanceDueFeePayAsset {
        let available: String
        let fee: String
    }

    struct InsufficientBalanceDueFeeNativeAsset {
        let available: String
        let fee: String
    }

    struct InsufficientBalanceDueConsumers {
        let minBalance: String
        let fee: String
    }

    enum InsufficientBalance {
        case dueFeePayAsset(InsufficientBalanceDueFeePayAsset)
        case dueFeeNativeAsset(InsufficientBalanceDueFeeNativeAsset)
        case dueConsumers(InsufficientBalanceDueConsumers)
    }

    struct DustRemainsDueSwap {
        let remaining: String
        let minBalance: String
    }

    enum DustRemains {
        case dueSwap(DustRemainsDueSwap)
    }

    struct PoolTradeLimit {
        let title: String
        let message: String

        /// `nil` when there is nothing to apply: an intermediate hop's cap is denominated in an asset
        /// the user never typed, and a spent correction budget means another tap would not converge.
        let applyTitle: String?
    }
}

extension SwapDisplayError.PoolTradeLimit {
    /// The inline issue on the setup screen and the alert on the confirm screen are both built here, so
    /// the amount named in the message is always the amount the action fills in.
    ///
    /// `nil` means there is nothing worth saying: the pool's own minimum is above anything it would
    /// accept, so no amount works and the generic "not enough liquidity" is the honest answer (FR-15).
    static func build(
        from failure: AssetExchangeTradeLimitFailure,
        canApply: Bool,
        viewModelFactory: BalanceViewModelFactoryFacadeProtocol,
        locale: Locale
    ) -> SwapDisplayError.PoolTradeLimit? {
        guard let suggestion = failure.suggestion() else {
            return nil
        }

        let assetInfo = failure.limitedAsset.assetDisplayInfo
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        func format(_ amount: Balance) -> String {
            viewModelFactory.amountFromValue(
                targetAssetInfo: assetInfo,
                value: amount.decimal(assetInfo: assetInfo)
            ).value(for: locale)
        }

        guard failure.isUserInputAdjustable else {
            // An intermediate hop, so there is no field to fill. Android quotes the exact cap here
            // rather than the undershot suggestion, because nothing is going to be applied from it.
            return .init(
                title: strings.swapFailurePoolTradeLimitTitle(),
                message: strings.swapFailurePoolTradeLimitRouteMessage(
                    failure.limitedAsset.asset.symbol,
                    format(failure.maxGivenAmount)
                ),
                applyTitle: nil
            )
        }

        return .init(
            title: strings.swapFailurePoolTradeLimitTitle(),
            message: strings.swapFailurePoolTradeLimitMessage(
                failure.limitedAsset.asset.symbol,
                format(suggestion)
            ),
            applyTitle: canApply ? strings.commonSwapMax() : nil
        )
    }
}
