import BigInt
import SoraFoundation

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
    func didReceiveSettingsState(isAvailable: Bool)
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
    func showSettings()
    func selectMaxPayAmount()
}

protocol SwapSetupInteractorInputProtocol: SwapBaseInteractorInputProtocol {
    func setup()
    func update(receiveChainAsset: ChainAsset?)
    func update(payChainAsset: ChainAsset?)
    func update(feeChainAsset: ChainAsset?)
}

protocol SwapSetupInteractorOutputProtocol: SwapBaseInteractorOutputProtocol {}

protocol SwapSetupWireframeProtocol: AnyObject, AlertPresentable, CommonRetryable,
    ErrorPresentable, SwapErrorPresentable, ShortTextInfoPresentable {
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
    func showSettings(
        from view: ControllerBackedProtocol?,
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    )
    func showInfo(
        from view: ControllerBackedProtocol?,
        title: LocalizableResource<String>,
        details: LocalizableResource<String>
    )
    func showConfirmation(
        from view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        feeChainAsset: ChainAsset,
        slippage: BigRational
    )
}

enum SwapSetupError: Error {
    case quote(Error, AssetConversion.QuoteArgs)
    case fetchFeeFailed(Error, TransactionFeeId)
    case price(Error, AssetModel.PriceId)
    case assetBalance(Error, ChainAssetId, AccountId)
}
