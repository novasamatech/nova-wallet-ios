import Foundation

extension SwapExecutionViewModelFactory {
    func createStepsViewModel(
        quote: AssetExchangeQuote,
        failure: SwapExecutionState.Failure,
        locale: Locale
    ) -> [SwapExecutionStepViewModel] {
        quote.metaOperations.enumerated().map { index, operation in
            let status: SwapExecutionStepViewModel.Status = if index < failure.operationIndex {
                .done
            } else if index == failure.operationIndex {
                .failed(
                    details: failure.getErrorDetails(for: locale),
                    fundsLocation: createFundsLocation(for: operation, failure: failure, locale: locale),
                    canViewTransaction: failure.txHash != nil
                )
            } else {
                .notRun(number: String(index + 1))
            }

            return SwapExecutionStepViewModel(
                title: createOperationDetails(operation, locale: locale),
                status: status
            )
        }
    }
}

private extension SwapExecutionViewModelFactory {
    func createFundsLocation(
        for operation: AssetExchangeMetaOperationProtocol,
        failure: SwapExecutionState.Failure,
        locale: Locale
    ) -> String? {
        guard failure.operationIndex > 0, failure.txHash == nil else {
            return nil
        }

        return R.string(preferredLanguages: locale.rLanguages).localizable.swapsExecutionFundsLocation(
            operation.assetIn.asset.symbol,
            operation.assetIn.chain.name
        )
    }
}
