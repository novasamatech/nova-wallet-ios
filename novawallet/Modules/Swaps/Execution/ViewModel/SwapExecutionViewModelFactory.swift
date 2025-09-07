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
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.swapsExecutionTransferDetails(operation.assetIn.asset.symbol, operation.assetOut.chain.name)
        case .swap:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.swapsExecutionSwapDetails(
                operation.assetIn.asset.symbol,
                operation.assetOut.asset.symbol,
                operation.assetOut.chain.name
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
            units: R.string(preferredLanguages: locale.rLanguages).localizable.secTimeUnits()
        )

        let currentOperationString = createOperationDetails(
            quote.metaOperations[currentOperationIndex],
            locale: locale
        )

        let totalOperations = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonOperations(format: quote.metaOperations.count)

        let details = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonOf(
            String(currentOperationIndex + 1),
            totalOperations
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

        let operationDescription = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.swapsExecutionSwapFailure(
            String(currentOperationIndex + 1),
            operationLabel
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

        let operationsString = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonOperations(format: quote.metaOperations.count)

        return .completed(.init(time: time, details: operationsString))
    }
}
