import Foundation

protocol SwapExecutionViewModelFactoryProtocol {
    func createInProgressViewModel(
        from quote: AssetExchangeQuote,
        currentOperationIndex: Int,
        remainedTime: TimeInterval,
        locale: Locale
    ) -> SwapExecutionViewModel
}

final class SwapExecutionViewModelFactory {
    private func createOperationDetails(
        _ operation: AssetExchangeMetaOperationProtocol,
        locale: Locale
    ) -> String {
        switch operation.label {
        case .transfer:
            return R.string.localizable.swapsExecutionTransferDetails(
                operation.assetIn.asset.symbol,
                operation.assetOut.chain.name,
                preferredLanguages: locale.rLanguages
            )
        case .swap:
            return R.string.localizable.swapsExecutionSwapDetails(
                operation.assetIn.asset.symbol,
                operation.assetOut.asset.symbol,
                operation.assetOut.chain.name,
                preferredLanguages: locale.rLanguages
            )
        }
    }
}

extension SwapExecutionViewModelFactory: SwapExecutionViewModelFactoryProtocol {
    func createInProgressViewModel(
        from quote: AssetExchangeQuote,
        currentOperationIndex: Int,
        remainedTime: TimeInterval,
        locale: Locale
    ) -> SwapExecutionViewModel {
        let remainedTimeViewModel = CountdownLoadingView.ViewModel(
            duration: UInt(remainedTime.rounded(.up)),
            units: R.string.localizable.secTimeUnits(preferredLanguages: locale.rLanguages)
        )

        let currentOperationString = createOperationDetails(
            quote.metaOperations[currentOperationIndex],
            locale: locale
        )

        let totalOperations = R.string.localizable.commonOperations(
            format: quote.metaOperations.count,
            preferredLanguages: locale.rLanguages
        )

        let details = R.string.localizable.commonOf(
            String(currentOperationIndex + 1),
            totalOperations,
            preferredLanguages: locale.rLanguages
        )

        return SwapExecutionViewModel.inProgress(
            .init(
                remainedTimeViewModel: remainedTimeViewModel,
                currentOperation: currentOperationString,
                details: details
            )
        )
    }
}
