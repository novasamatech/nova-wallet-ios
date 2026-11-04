import Foundation

typealias SwapPoolTradeLimitValidatingClosure =
    (AssetExchangeRoute, @escaping (SwapPoolTradeLimitCheck) -> Void) -> Void

extension SwapDataValidatorFactory {
    func noPoolTradeLimitExceeded(
        params: SwapModel,
        remoteValidatingClosure: @escaping SwapPoolTradeLimitValidatingClosure,
        poolTradeLimitAction: SwapPoolTradeLimitApplying?,
        locale: Locale
    ) -> DataValidating {
        var failedCheck: SwapPoolTradeLimitCheck = .withinLimits
        weak var validation: AsyncWarningConditionViolation?

        let poolTradeLimitValidation = AsyncWarningConditionViolation(
            onWarning: { [weak self] delegate in
                self?.presentPoolTradeLimitCheck(
                    failedCheck,
                    params: params,
                    poolTradeLimitAction: poolTradeLimitAction,
                    retryAction: { _ = validation?.validate(notifying: delegate) },
                    locale: locale
                )
            },
            preservesCondition: { completion in
                guard let route = params.quote?.route else {
                    completion(true)
                    return
                }

                remoteValidatingClosure(route) { check in
                    failedCheck = check
                    completion(check == .withinLimits)
                }
            }
        )

        validation = poolTradeLimitValidation

        return poolTradeLimitValidation
    }
}

private extension SwapDataValidatorFactory {
    func presentPoolTradeLimitCheck(
        _ check: SwapPoolTradeLimitCheck,
        params: SwapModel,
        poolTradeLimitAction: SwapPoolTradeLimitApplying?,
        retryAction: @escaping () -> Void,
        locale: Locale
    ) {
        let chargesCommission = params.quote?.commission != nil

        switch check {
        case .withinLimits:
            return
        case let .belowMinimum(failure):
            presentPoolTradeMinimum(
                for: failure,
                asset: failure.direction == .sell ? params.payChainAsset : params.receiveChainAsset,
                chargesCommission: chargesCommission,
                locale: locale
            )
        case let .blocked(failure):
            presentPoolTradeLimit(
                for: failure,
                chargesCommission: chargesCommission,
                poolTradeLimitAction: poolTradeLimitAction,
                locale: locale
            )
        case .minBalanceUnavailable:
            guard let view else {
                return
            }

            presentable.presentMinBalanceUnavailable(from: view, retryAction: retryAction, locale: locale)
        }
    }

    func presentPoolTradeLimit(
        for failure: AssetExchangeTradeLimitFailure?,
        chargesCommission: Bool,
        poolTradeLimitAction: SwapPoolTradeLimitApplying?,
        locale: Locale
    ) {
        guard let view else {
            return
        }

        guard let failure else {
            presentable.presentNotEnoughLiquidity(from: view, locale: locale)

            return
        }

        guard let displayError = SwapDisplayError.PoolTradeLimit.build(
            from: failure,
            canApply: failure.isUserInputAdjustable && poolTradeLimitAction != nil,
            chargesCommission: chargesCommission,
            viewModelFactory: balanceViewModelFactoryFacade,
            locale: locale
        ) else {
            presentable.presentNotEnoughLiquidity(from: view, locale: locale)

            return
        }

        presentable.presentPoolTradeLimit(
            from: view,
            reason: displayError,
            applyAction: {
                guard let suggestion = failure.suggestion(chargesCommission: chargesCommission) else {
                    return
                }

                poolTradeLimitAction?(suggestion, failure.direction)
            },
            locale: locale
        )
    }

    func presentPoolTradeMinimum(
        for failure: AssetExchangeTradeMinimumFailure,
        asset: ChainAsset,
        chargesCommission: Bool,
        locale: Locale
    ) {
        guard let view else {
            return
        }

        let minAmount = failure.formattedUserMinimum(
            for: asset,
            chargesCommission: chargesCommission,
            viewModelFactory: balanceViewModelFactoryFacade,
            locale: locale
        )

        presentable.presentPoolTradeMinimum(from: view, minAmount: minAmount, locale: locale)
    }
}
