import Foundation
import SoraFoundation

final class SwapExecutionPresenter {
    weak var view: SwapExecutionViewProtocol?
    let wireframe: SwapExecutionWireframeProtocol
    let interactor: SwapExecutionInteractorInputProtocol

    let model: SwapExecutionModel
    let executionViewModelFactory: SwapExecutionViewModelFactoryProtocol
    let detailsViewModelFactory: SwapDetailsViewModelFactoryProtocol

    var quote: AssetExchangeQuote {
        model.quote
    }

    var chainAssetIn: ChainAsset {
        model.chainAssetIn
    }

    var chainAssetOut: ChainAsset {
        model.chainAssetOut
    }

    private var state: SwapExecutionState?
    private var execTimer: CountdownTimer?

    init(
        model: SwapExecutionModel,
        interactor: SwapExecutionInteractorInputProtocol,
        wireframe: SwapExecutionWireframeProtocol,
        executionViewModelFactory: SwapExecutionViewModelFactoryProtocol,
        detailsViewModelFactory: SwapDetailsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.model = model
        self.interactor = interactor
        self.wireframe = wireframe
        self.executionViewModelFactory = executionViewModelFactory
        self.detailsViewModelFactory = detailsViewModelFactory
        self.localizationManager = localizationManager
    }

    deinit {
        clearTimer()
    }

    private func provideExecutionViewModel() {
        let viewModel: SwapExecutionViewModel? = switch state {
        case let .inProgress(operationIndex):
            executionViewModelFactory.createInProgressViewModel(
                from: quote,
                currentOperationIndex: operationIndex,
                remainedTime: execTimer?.remainedInterval ?? 0,
                locale: selectedLocale
            )
        case let .completed(date):
            executionViewModelFactory.createCompletedViewModel(
                quote: quote,
                for: date,
                locale: selectedLocale
            )
        case let .failed(operationIndex, date):
            executionViewModelFactory.createFailedViewModel(
                quote: quote,
                currentOperationIndex: operationIndex,
                for: date,
                locale: selectedLocale
            )
        case nil:
            nil
        }

        guard let viewModel else {
            return
        }

        view?.didReceiveExecution(viewModel: viewModel)
    }

    private func provideAssetInViewModel() {
        let viewModel = detailsViewModelFactory.assetViewModel(
            chainAsset: chainAssetIn,
            amount: model.quote.route.amountIn,
            priceData: model.prices[chainAssetIn.chainAssetId],
            locale: selectedLocale
        )

        view?.didReceiveAssetIn(viewModel: viewModel)
    }

    private func provideAssetOutViewModel() {
        let viewModel = detailsViewModelFactory.assetViewModel(
            chainAsset: chainAssetOut,
            amount: quote.route.amountOut,
            priceData: model.prices[chainAssetOut.chainAssetId],
            locale: selectedLocale
        )

        view?.didReceiveAssetOut(viewModel: viewModel)
    }

    private func provideRateViewModel() {
        let params = RateParams(
            assetDisplayInfoIn: chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: chainAssetOut.assetDisplayInfo,
            amountIn: model.quote.route.amountIn,
            amountOut: model.quote.route.amountOut
        )

        let viewModel = detailsViewModelFactory.rateViewModel(from: params, locale: selectedLocale)

        view?.didReceiveRate(viewModel: .loaded(value: viewModel))
    }

    private func provideRouteViewModel() {
        let viewModel = detailsViewModelFactory.routeViewModel(from: model.quote.metaOperations)

        view?.didReceiveRoute(viewModel: .loaded(value: viewModel))
    }

    private func providePriceDifferenceViewModel() {
        let params = RateParams(
            assetDisplayInfoIn: chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: chainAssetOut.assetDisplayInfo,
            amountIn: quote.route.amountIn,
            amountOut: quote.route.amountOut
        )

        if let viewModel = detailsViewModelFactory.priceDifferenceViewModel(
            rateParams: params,
            priceIn: model.prices[chainAssetIn.chainAssetId],
            priceOut: model.prices[chainAssetOut.chainAssetId],
            locale: selectedLocale
        ) {
            view?.didReceivePriceDifference(viewModel: .loaded(value: viewModel))
        } else {
            view?.didReceivePriceDifference(viewModel: nil)
        }
    }

    private func provideSlippageViewModel() {
        let viewModel = detailsViewModelFactory.slippageViewModel(slippage: model.fee.slippage, locale: selectedLocale)
        view?.didReceiveSlippage(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        let feeInFiat = model.fee.calculateTotalFeeInFiat(
            assetIn: chainAssetIn,
            assetInPrice: model.payAssetPrice,
            feeAsset: model.feeAsset,
            feeAssetPrice: model.feeAssetPrice
        )

        let viewModel = detailsViewModelFactory.feeViewModel(
            amountInFiat: feeInFiat,
            isEditable: false,
            priceData: model.feeAssetPrice,
            locale: selectedLocale
        )

        view?.didReceiveTotalFee(viewModel: .loaded(value: viewModel))
    }

    private func updateSwapDetails() {
        provideRateViewModel()
        providePriceDifferenceViewModel()
        provideSlippageViewModel()
        provideRouteViewModel()
        provideFeeViewModel()
    }

    private func updateSwapAssets() {
        provideAssetInViewModel()
        provideAssetOutViewModel()
    }

    private func clearTimer() {
        execTimer?.delegate = nil
        execTimer?.stop()
        execTimer = nil
    }

    private func restartCountdownTimer(for reminedExecutionTime: TimeInterval) {
        let currentTimer = execTimer ?? CountdownTimer()

        currentTimer.stop()
        currentTimer.delegate = self
        currentTimer.start(with: reminedExecutionTime)

        execTimer = currentTimer
    }

    private func updateInProgressStateIfNeeded(for newOperationIndex: Int) {
        if case let .inProgress(operationIndex) = state, operationIndex == newOperationIndex {
            return
        }

        let remainedExecutionTime = model.quote.totalExecutionTime(from: newOperationIndex)

        state = .inProgress(newOperationIndex)

        restartCountdownTimer(for: remainedExecutionTime)

        provideExecutionViewModel()
    }

    private func updateCompletedStateIfNeeded() {
        clearTimer()

        state = .completed(Date())

        provideExecutionViewModel()
    }

    private func updateFailedStateIfNeeded() {
        guard case let .inProgress(operationIndex) = state else { return }

        clearTimer()

        state = .failed(operationIndex, Date())

        provideExecutionViewModel()
    }
}

extension SwapExecutionPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {}

    func didCountdown(remainedInterval: TimeInterval) {
        view?.didUpdateExecution(remainedTime: UInt(remainedInterval.rounded(.up)))
    }

    func didStop(with remainedInterval: TimeInterval) {
        view?.didUpdateExecution(remainedTime: UInt(remainedInterval.rounded(.up)))
    }
}

extension SwapExecutionPresenter: SwapExecutionPresenterProtocol {
    func setup() {
        provideExecutionViewModel()
        updateSwapDetails()
        updateSwapAssets()

        updateInProgressStateIfNeeded(for: 0)

        interactor.submit(using: model.fee)
    }

    func showRateInfo() {
        wireframe.showRateInfo(from: view)
    }

    func showPriceDifferenceInfo() {
        let title = LocalizableResource {
            R.string.localizable.swapsSetupPriceDifference(
                preferredLanguages: $0.rLanguages
            )
        }
        let details = LocalizableResource {
            R.string.localizable.swapsSetupPriceDifferenceDescription(
                preferredLanguages: $0.rLanguages
            )
        }
        wireframe.showInfo(
            from: view,
            title: title,
            details: details
        )
    }

    func showSlippageInfo() {
        wireframe.showSlippageInfo(from: view)
    }

    func showTotalFeeInfo() {
        wireframe.showFeeInfo(from: view)
    }

    func activateDone() {
        wireframe.complete(on: view, payChainAsset: chainAssetIn)
    }

    func activateTryAgain() {
        guard case let .failed(operationIndex, _) = state else {
            return
        }

        let payChainAsset = quote.metaOperations[operationIndex].assetIn
        let receiveChainAsset = chainAssetOut

        wireframe.showSwapSetup(
            from: view,
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset
        )
    }
}

extension SwapExecutionPresenter: SwapExecutionInteractorOutputProtocol {
    func didStartExecution(for operationIndex: Int) {
        updateInProgressStateIfNeeded(for: operationIndex)
    }

    func didCompleteFullExecution(received _: Balance) {
        updateCompletedStateIfNeeded()
    }

    func didFailExecution(with _: Error) {
        updateFailedStateIfNeeded()
    }
}

extension SwapExecutionPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideExecutionViewModel()
            updateSwapAssets()
            updateSwapDetails()
        }
    }
}
