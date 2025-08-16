import Foundation
import Foundation_iOS

protocol SwapExecutionViewModelFactoryProtocol {
    func createInProgressViewModel(
        from quote: AssetExchangeQuote,
        currentOperationIndex: Int,
        remainedTime: TimeInterval,
        locale: Locale
    ) -> SwapExecutionViewModel

    func createFailedViewModel(
        quote: AssetExchangeQuote,
        failure: SwapExecutionState.Failure,
        locale: Locale
    ) -> SwapExecutionViewModel

    func createCompletedViewModel(
        quote: AssetExchangeQuote,
        for date: Date,
        locale: Locale
    ) -> SwapExecutionViewModel
}

final class SwapExecutionViewModelFactory {
    let dateFormatter: LocalizableResource<DateFormatter>

    init(dateFormatter: LocalizableResource<DateFormatter> = DateFormatter.shortDateAndTime) {
        self.dateFormatter = dateFormatter
    }

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

        return .inProgress(
            .init(
                remainedTimeViewModel: remainedTimeViewModel,
                currentOperation: currentOperationString,
                details: details
            )
        )
    }

    func createFailedViewModel(
        quote: AssetExchangeQuote,
        failure: SwapExecutionState.Failure,
        locale: Locale
    ) -> SwapExecutionViewModel {
        let time = dateFormatter.value(for: locale).string(from: failure.date)
        let currentOperationIndex = failure.operationIndex

        let operationLabel = quote.metaOperations[currentOperationIndex].label.getTitle(for: locale)

        let operationDescription = R.string.localizable.swapsExecutionSwapFailure(
            String(currentOperationIndex + 1),
            operationLabel,
            preferredLanguages: locale.rLanguages
        )

        let details = if let errorDetails = failure.getErrorDetails(for: locale) {
            operationDescription + ": " + errorDetails
        } else {
            operationDescription
        }

        return .failed(.init(time: time, details: details))
    }

    func createCompletedViewModel(
        quote: AssetExchangeQuote,
        for date: Date,
        locale: Locale
    ) -> SwapExecutionViewModel {
        let time = dateFormatter.value(for: locale).string(from: date)

        let operationsString = R.string.localizable.commonOperations(
            format: quote.metaOperations.count,
            preferredLanguages: locale.rLanguages
        )

        return .completed(.init(time: time, details: operationsString))
    }
}
