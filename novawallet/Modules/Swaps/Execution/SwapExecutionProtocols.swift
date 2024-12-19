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
}

protocol SwapExecutionInteractorInputProtocol: AnyObject {
    func submit(using estimation: AssetExchangeFee)
}

protocol SwapExecutionInteractorOutputProtocol: AnyObject {
    func didStartExecution(for operationIndex: Int)
    func didCompleteFullExecution(received amount: Balance)
    func didFailExecution(with error: Error)
}

protocol SwapExecutionWireframeProtocol: ShortTextInfoPresentable, MessageSheetPresentable, AlertPresentable,
    ErrorPresentable, ExtrinsicSigningErrorHandling {
    func complete(
        on view: ControllerBackedProtocol?,
        receiveChainAsset: ChainAsset
    )

    func showSwapSetup(
        from view: SwapExecutionViewProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset
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
