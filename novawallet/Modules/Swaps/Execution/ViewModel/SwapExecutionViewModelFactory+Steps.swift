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
