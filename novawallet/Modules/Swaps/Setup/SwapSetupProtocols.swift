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
    func didReceiveAmountInputPrice(receiveViewModel: SwapPriceDifferenceViewModel?)
    func didReceiveTitle(receiveViewModel viewModel: TitleHorizontalMultiValueView.Model)
    func didReceiveRate(viewModel: LoadableViewModelState<String>)
    func didReceiveNetworkFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>)
    func didReceiveDetailsState(isAvailable: Bool)
    func didReceiveSettingsState(isAvailable: Bool)
    func didReceive(issues: [SwapSetupViewIssue])
    func didSetNotification(message: String?)
    func didReceive(focus: TextFieldFocus?)
    func didStartLoading()
    func didStopLoading()
}

protocol SwapSetupPresenterProtocol: AnyObject {
    func setup()
    func selectPayToken()
    func selectReceiveToken()
    func proceed()
    func flip(currentFocus: TextFieldFocus?)
    func updatePayAmount(_ amount: Decimal?)
    func updateReceiveAmount(_ amount: Decimal?)
    func showFeeActions()
    func showFeeInfo()
    func showRateInfo()
    func showSettings()
    func selectMaxPayAmount()
    func depositInsufficientToken()
}

protocol SwapSetupInteractorInputProtocol: SwapBaseInteractorInputProtocol {
    func setup()
    func update(receiveChainAsset: ChainAsset?)
    func update(payChainAsset: ChainAsset?)
    func update(feeChainAsset: ChainAsset?)
    func retryRemoteSubscription()
}

protocol SwapSetupInteractorOutputProtocol: SwapBaseInteractorOutputProtocol {
    func didReceiveCanPayFeeInPayAsset(_ value: Bool, chainAssetId: ChainAssetId)
    func didReceiveQuoteDataChanged()
    func didReceive(setupError: SwapSetupError)
}

protocol SwapSetupWireframeProtocol: SwapBaseWireframeProtocol,
    ShortTextInfoPresentable,
    PurchasePresentable,
    FeeAssetSelectionPresentable {
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
        initState: SwapConfirmInitState
    )

    func showGetTokenOptions(
        form view: ControllerBackedProtocol?,
        purchaseHadler: PurchaseFlowManaging,
        destinationChainAsset: ChainAsset,
        locale: Locale
    )
}

enum SwapSetupError: Error {
    case payAssetSetFailed(Error)
    case remoteSubscription(Error)
}

enum SwapSetupViewIssue: Equatable {
    case zeroBalance
    case insufficientBalance
    case minBalanceViolation(String)
    case noLiqudity
    case zeroReceiveAmount
}
