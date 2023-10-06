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
    func didReceiveNetworkFee(viewModel: LoadableViewModelState<BalanceViewModelProtocol>)
}

protocol SwapSetupPresenterProtocol: AnyObject {
    func setup()
    func selectPayToken()
    func selectReceiveToken()
    func proceed()
    func swap()
    func updatePayAmount(_ amount: Decimal?)
    func updateReceiveAmount(_ amount: Decimal?)
}

protocol SwapSetupInteractorInputProtocol: AnyObject {
    func setup()
    func set(chainModel: ChainModel)
    func calculateQuote(for args: AssetConversion.QuoteArgs)
    func calculateFee(for args: FeeArgs)
    func performSubscriptions(chainAsset: ChainAsset)
}

protocol SwapSetupInteractorOutputProtocol: AnyObject {
    func didReceive(quote: AssetConversion.Quote)
    func didReceive(fee: BigUInt?)
    func didReceive(error: SwapSetupError)
    func didReceive(price: PriceData?, priceId: AssetModel.PriceId)
}

protocol SwapSetupWireframeProtocol: AnyObject, AlertPresentable, CommonRetryable, ErrorPresentable {
    func showPayTokenSelection(
        from view: ControllerBackedProtocol?,
        completionHandler: @escaping (ChainAsset) -> Void
    )
    func showReceiveTokenSelection(
        from view: ControllerBackedProtocol?,
        completionHandler: @escaping (ChainAsset) -> Void
    )
}

enum SwapSetupError: Error {
    case quote(Error)
    case fetchFeeFailed(Error)
    case price(Error, AssetModel.PriceId)
}

struct FeeArgs {
    let assetIn: ChainAssetId
    let amountIn: BigUInt
    let assetOut: ChainAssetId
    let amountOut: BigUInt
    let direction: AssetConversion.Direction
    let slippage: BigUInt
}
