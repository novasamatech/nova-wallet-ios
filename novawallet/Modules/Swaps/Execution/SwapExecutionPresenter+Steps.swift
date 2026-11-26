import Foundation

extension SwapExecutionPresenter {
    func provideStepsViewModel() {
        guard case let .failed(failure) = state else {
            return
        }

        let viewModel = executionViewModelFactory.createStepsViewModel(
            quote: quote,
            failure: failure,
            locale: selectedLocale
        )

        view?.didReceiveSteps(viewModel: viewModel)
    }

    func showFailedTransaction() {
        guard
            let view,
            case let .failed(failure) = state,
            let txHash = failure.txHash else {
            return
        }

        let chain = quote.metaOperations[failure.operationIndex].assetIn.chain

        wireframe.presentTransactionHashOptions(
            from: view,
            transactionHash: txHash,
            explorers: chain.explorers,
            locale: selectedLocale
        )
    }
}
