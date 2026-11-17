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
        failure: SwapExecutionState.Failure,
        locale: Locale
    ) -> SwapExecutionViewModel

    func createCompletedViewModel(
        for date: Date,
        receivedAmount: String,
        locale: Locale
    ) -> SwapExecutionViewModel

    func createStepsViewModel(
        quote: AssetExchangeQuote,
        failure: SwapExecutionState.Failure,
        locale: Locale
    ) -> [SwapExecutionStepViewModel]
}

final class SwapExecutionViewModelFactory {
    let dateFormatter: LocalizableResource<DateFormatter>

    init(dateFormatter: LocalizableResource<DateFormatter> = DateFormatter.shortDateAndTime) {
        self.dateFormatter = dateFormatter
    }

    func createOperationDetails(
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
        failure: SwapExecutionState.Failure,
        locale: Locale
    ) -> SwapExecutionViewModel {
        let time = dateFormatter.value(for: locale).string(from: failure.date)

        return .failed(.init(time: time))
    }

    func createCompletedViewModel(
        for date: Date,
        receivedAmount: String,
        locale: Locale
    ) -> SwapExecutionViewModel {
        let time = dateFormatter.value(for: locale).string(from: date)

        return .completed(.init(time: time, amount: Constants.plusSign + receivedAmount))
    }
}

private extension SwapExecutionViewModelFactory {
    enum Constants {
        static let plusSign = "+"
    }
}
