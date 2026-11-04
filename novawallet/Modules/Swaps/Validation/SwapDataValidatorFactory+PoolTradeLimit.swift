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
        let context = SwapPoolTradeLimitValidatingContext(
            params: params,
            remoteValidatingClosure: remoteValidatingClosure,
            poolTradeLimitAction: poolTradeLimitAction,
            locale: locale
        )

        var failedCheck: SwapPoolTradeLimitCheck = .withinLimits

        return AsyncWarningConditionViolation(
            onWarning: { [weak self] delegate in
                self?.presentPoolTradeLimitCheck(failedCheck, context: context, delegate: delegate)
            },
            preservesCondition: { completion in
                context.check { check in
                    failedCheck = check
                    completion(check == .withinLimits)
                }
            }
        )
    }
}

private struct SwapPoolTradeLimitValidatingContext {
    let params: SwapModel
    let remoteValidatingClosure: SwapPoolTradeLimitValidatingClosure
    let poolTradeLimitAction: SwapPoolTradeLimitApplying?
    let locale: Locale

    var chargesCommission: Bool {
        params.quote?.commission != nil
    }

    func check(completion: @escaping (SwapPoolTradeLimitCheck) -> Void) {
        guard let route = params.quote?.route else {
            completion(.withinLimits)

            return
        }

        remoteValidatingClosure(route, completion)
    }
}

private extension SwapDataValidatorFactory {
    func presentPoolTradeLimitCheck(
        _ check: SwapPoolTradeLimitCheck,
        context: SwapPoolTradeLimitValidatingContext,
        delegate: DataValidatingDelegate
    ) {
        switch check {
        case .withinLimits:
            return
        case let .belowMinimum(failure):
            presentPoolTradeMinimum(
                for: failure,
                chargesCommission: context.chargesCommission,
                locale: context.locale
            )
        case let .blocked(failure):
            presentPoolTradeLimit(
                for: failure,
                chargesCommission: context.chargesCommission,
                poolTradeLimitAction: context.poolTradeLimitAction,
                locale: context.locale
            )
        case .minBalanceUnavailable:
            guard let view else {
                return
            }

            presentable.presentMinBalanceUnavailable(
                from: view,
                retryAction: { [weak self] in
                    self?.recheckPoolTradeLimits(context: context, delegate: delegate)
                },
                locale: context.locale
            )
        }
    }

    func recheckPoolTradeLimits(
        context: SwapPoolTradeLimitValidatingContext,
        delegate: DataValidatingDelegate
    ) {
        context.check { [weak self] check in
            guard check != .withinLimits else {
                delegate.didCompleteAsyncHandling()

                return
            }

            self?.presentPoolTradeLimitCheck(check, context: context, delegate: delegate)
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
