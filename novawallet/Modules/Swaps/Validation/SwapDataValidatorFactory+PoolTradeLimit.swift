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

        return AsyncErrorConditionViolation(
            onError: { [weak self] in
                switch failedCheck {
                case .withinLimits:
                    return
                case let .belowMinimum(failure):
                    self?.presentPoolTradeMinimum(
                        for: failure,
                        chargesCommission: params.quote?.commission != nil,
                        locale: locale
                    )
                case let .blocked(failure):
                    self?.presentPoolTradeLimit(
                        for: failure,
                        poolTradeLimitAction: poolTradeLimitAction,
                        locale: locale
                    )
                }
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
    }
}

private extension SwapDataValidatorFactory {
    func presentPoolTradeLimit(
        for failure: AssetExchangeTradeLimitFailure?,
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
                guard let suggestion = failure.suggestion() else {
                    return
                }

                poolTradeLimitAction?(suggestion, failure.direction)
            },
            locale: locale
        )
    }

    func presentPoolTradeMinimum(
        for failure: AssetExchangeTradeMinimumFailure,
        chargesCommission: Bool,
        locale: Locale
    ) {
        guard let view else {
            return
        }

        let minAmount = failure.formattedUserMinimum(
            chargesCommission: chargesCommission,
            viewModelFactory: balanceViewModelFactoryFacade,
            locale: locale
        )

        presentable.presentPoolTradeMinimum(from: view, minAmount: minAmount, locale: locale)
    }
}
