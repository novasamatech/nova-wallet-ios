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
        var failure: AssetExchangeTradeLimitFailure?

        return AsyncErrorConditionViolation(
            onError: { [weak self] in
                guard let view = self?.view, let viewModelFactory = self?.balanceViewModelFactoryFacade else {
                    return
                }

                guard let failure else {
                    self?.presentable.presentNotEnoughLiquidity(from: view, locale: locale)

                    return
                }

                guard let displayError = SwapDisplayError.PoolTradeLimit.build(
                    from: failure,
                    canApply: failure.isUserInputAdjustable && poolTradeLimitAction != nil,
                    viewModelFactory: viewModelFactory,
                    locale: locale
                ) else {
                    self?.presentable.presentNotEnoughLiquidity(from: view, locale: locale)

                    return
                }

                self?.presentable.presentPoolTradeLimit(
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
            },
            preservesCondition: { completion in
                guard let route = params.quote?.route else {
                    completion(true)

                    return
                }

                remoteValidatingClosure(route) { check in
                    switch check {
                    case .withinLimits:
                        completion(true)
                    case let .blocked(reportable):
                        failure = reportable
                        completion(false)
                    }
                }
            }
        )
    }
}
