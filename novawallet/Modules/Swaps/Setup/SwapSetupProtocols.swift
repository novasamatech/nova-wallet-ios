import BigInt

protocol SwapSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveButtonState(title: String, enabled: Bool)
    func didReceiveInputChainAsset(payViewModel viewModel: SwapAssetInputViewModel)
    func didReceiveAmount(payInputViewModel inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(payViewModel: String?)
    func didReceiveTitle(payViewModel viewModel: TitleHorizontalMultiValueView.Model)
    func didReceiveInputChainAsset(receiveViewModel viewModel: SwapAssetInputViewModel)
    func didReceiveAmount(receiveInputViewModel inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(receiveViewModel: String?)
    func didReceiveTitle(receiveViewModel viewModel: TitleHorizontalMultiValueView.Model)
    func didReceiveRate(viewModel: LoadableViewModelState<String>)
    func didReceiveNetworkFee(viewModel: LoadableViewModelState<SwapFeeViewModel>)
    func didReceiveDetailsState(isAvailable: Bool)
}

protocol SwapSetupPresenterProtocol: AnyObject {
    func setup()
    func selectPayToken()
    func selectReceiveToken()
    func proceed()
    func swap()
    func updatePayAmount(_ amount: Decimal?)
    func updateReceiveAmount(_ amount: Decimal?)
    func showFeeActions()
    func showFeeInfo()
    func showRateInfo()
}

protocol SwapSetupInteractorInputProtocol: AnyObject {
    func setup()
    func update(receiveChainAsset: ChainAsset)
    func update(payChainAsset: ChainAsset)
    func calculateQuote(for args: AssetConversion.QuoteArgs)
    func calculateFee(for quote: AssetConversion.Quote, slippage: SwapSlippage) -> TransactionFeeId?
}

protocol SwapSetupInteractorOutputProtocol: AnyObject {
    func didReceive(quote: AssetConversion.Quote, for quoteArgs: AssetConversion.QuoteArgs)
    func didReceive(fee: BigUInt?, transactionId: TransactionFeeId)
    func didReceive(error: SwapSetupError)
    func didReceive(price: PriceData?, priceId: AssetModel.PriceId)
}

protocol SwapSetupWireframeProtocol: AnyObject, AlertPresentable, CommonRetryable, ErrorPresentable {
    func showPayTokenSelection(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset?,
        completionHandler: @escaping (ChainAsset) -> Void
    )
    func showReceiveTokenSelection(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset?,
        completionHandler: @escaping (ChainAsset) -> Void
    )
}

enum SwapSetupError: Error {
    case quote(Error, AssetConversion.QuoteArgs)
    case fetchFeeFailed(Error, TransactionFeeId)
    case price(Error, AssetModel.PriceId)
}

struct SwapSlippage {
    let direction: AssetConversion.Direction
    let slippage: BigUInt
}
