protocol SwapExecutionViewProtocol: ControllerBackedProtocol {
    func didReceiveExecution(viewModel: SwapExecutionViewModel)
    func didUpdateExecution(remainedTime: UInt)
    func didReceiveAssetIn(viewModel: SwapAssetAmountViewModel)
    func didReceiveAssetOut(viewModel: SwapAssetAmountViewModel)
    func didReceiveRate(viewModel: LoadableViewModelState<String>)
    func didReceiveRoute(viewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>)
    func didReceivePriceDifference(viewModel: LoadableViewModelState<DifferenceViewModel>?)
    func didReceiveSlippage(viewModel: String)
    func didReceiveTotalFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>)
    func didReceiveSteps(viewModel: [SwapExecutionStepViewModel])
}

protocol SwapExecutionPresenterProtocol: AnyObject {
    func setup()
    func showRateInfo()
    func showPriceDifferenceInfo()
    func showSlippageInfo()
    func showTotalFeeInfo()
    func showRouteDetails()
    func activateDone()
    func activateTryAgain()
    func activateClose()
    func showFailedTransaction()
}

protocol SwapExecutionInteractorInputProtocol: AnyObject {
    func submit(using estimation: AssetExchangeFee)
}

protocol SwapExecutionInteractorOutputProtocol: AnyObject {
    func didStartExecution(for operationIndex: Int)
    func didCompleteFullExecution(received amount: Balance)
    func didFailExecution(with failure: AssetExchangeOperationFailure)
}

protocol SwapExecutionWireframeProtocol: ShortTextInfoPresentable, MessageSheetPresentable, AlertPresentable,
    ErrorPresentable, ExtrinsicSigningErrorHandling, OperationIdOptionsPresentable {
    func complete(
        on view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    )

    func showSwapSetup(
        from view: SwapExecutionViewProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
    )

    func close(
        on view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        isSwapCompleted: Bool
    )

    func showRouteDetails(
        from view: ControllerBackedProtocol?,
        quote: AssetExchangeQuote,
        fee: AssetExchangeFee
    )

    func showFeeDetails(
        from view: ControllerBackedProtocol?,
        operations: [AssetExchangeMetaOperationProtocol],
        fee: AssetExchangeFee
    )
}
