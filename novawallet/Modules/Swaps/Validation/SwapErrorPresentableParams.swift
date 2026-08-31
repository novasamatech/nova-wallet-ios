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

        let applyTitle: String?
    }
}

extension SwapDisplayError.PoolTradeLimit {
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
