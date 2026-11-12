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
                title: createStepTitle(for: operation, locale: locale),
                status: status
            )
        }
    }
}

private extension SwapExecutionViewModelFactory {
    func createStepTitle(
        for operation: AssetExchangeMetaOperationProtocol,
        locale: Locale
    ) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return switch operation.label {
        case .transfer:
            strings.swapsExecutionStepTransfer(
                operation.assetIn.asset.symbol,
                operation.assetIn.chain.name,
                operation.assetOut.chain.name
            )
        case .swap:
            strings.swapsExecutionStepSwap(
                operation.assetIn.asset.symbol,
                operation.assetOut.asset.symbol,
                operation.assetOut.chain.name
            )
        }
    }
}
