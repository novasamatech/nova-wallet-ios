import Foundation
import Foundation_iOS

final class SwapExecutionPresenter {
    weak var view: SwapExecutionViewProtocol?
    let wireframe: SwapExecutionWireframeProtocol
    let interactor: SwapExecutionInteractorInputProtocol

    let model: SwapExecutionModel
    let executionViewModelFactory: SwapExecutionViewModelFactoryProtocol
    let detailsViewModelFactory: SwapDetailsViewModelFactoryProtocol
    let priceStore: AssetExchangePriceStoring

    var quote: AssetExchangeQuote {
        model.quote
    }

    var chainAssetIn: ChainAsset {
        model.chainAssetIn
    }

    var chainAssetOut: ChainAsset {
        model.chainAssetOut
    }

    var payAssetPrice: PriceData? {
        priceStore.fetchPrice(for: model.chainAssetIn.chainAssetId)
    }

    var receiveAssetPrice: PriceData? {
        priceStore.fetchPrice(for: model.chainAssetOut.chainAssetId)
    }

    var feeAssetPrice: PriceData? {
        priceStore.fetchPrice(for: model.feeAsset.chainAssetId)
    }

    private var state: SwapExecutionState?
    private var execTimer: CountdownTimer?

    init(
        model: SwapExecutionModel,
        interactor: SwapExecutionInteractorInputProtocol,
        wireframe: SwapExecutionWireframeProtocol,
        executionViewModelFactory: SwapExecutionViewModelFactoryProtocol,
        detailsViewModelFactory: SwapDetailsViewModelFactoryProtocol,
        priceStore: AssetExchangePriceStoring,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.model = model
        self.interactor = interactor
        self.wireframe = wireframe
        self.executionViewModelFactory = executionViewModelFactory
        self.detailsViewModelFactory = detailsViewModelFactory
        self.priceStore = priceStore
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
        case let .failed(failure):
            executionViewModelFactory.createFailedViewModel(
                quote: quote,
                failure: failure,
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
            priceData: payAssetPrice,
            locale: selectedLocale
        )

        view?.didReceiveAssetIn(viewModel: viewModel)
    }

    private func provideAssetOutViewModel() {
        let viewModel = detailsViewModelFactory.assetViewModel(
            chainAsset: chainAssetOut,
            amount: quote.route.amountOut,
            priceData: receiveAssetPrice,
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
            priceIn: payAssetPrice,
            priceOut: receiveAssetPrice,
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
            matching: model.quote.metaOperations,
            priceStore: priceStore
        )

        let viewModel = detailsViewModelFactory.feeViewModel(
            amountInFiat: feeInFiat,
            isEditable: false,
            currencyId: feeAssetPrice?.currencyId,
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

    private func updateFailedStateIfNeeded(with error: Error) {
        guard case let .inProgress(operationIndex) = state else { return }

        clearTimer()

        let model = SwapExecutionState.Failure(
            operationIndex: operationIndex,
            date: Date(),
            error: error
        )

        state = .failed(model)

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

    func showRouteDetails() {
        wireframe.showRouteDetails(
            from: view,
            quote: model.quote,
            fee: model.fee
        )
    }

    func showPriceDifferenceInfo() {
        let title = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsSetupPriceDifference()
        }
        let details = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsSetupPriceDifferenceDescription()
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
        wireframe.showFeeDetails(
            from: view,
            operations: model.quote.metaOperations,
            fee: model.fee
        )
    }

    func activateDone() {
        wireframe.complete(on: view, receiveChainAsset: chainAssetOut)
    }

    func activateTryAgain() {
        guard case let .failed(model) = state else {
            return
        }

        let payChainAsset = quote.metaOperations[model.operationIndex].assetIn
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

    func didFailExecution(with error: Error) {
        updateFailedStateIfNeeded(with: error)

        _ = wireframe.handleExtrinsicSigningErrorPresentation(
            error,
            view: view,
            closeAction: .dismissAllModals,
            completionClosure: nil
        )
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
