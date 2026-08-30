import Foundation
import BigInt
import Foundation_iOS

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
    func didReceiveRoute(viewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>)
    func didReceiveExecutionTime(viewModel: LoadableViewModelState<String>)
    func didReceiveNetworkFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>)
    func didReceiveCommissionDisclosure(viewModel: String?)
    func didReceiveDetailsState(isAvailable: Bool)
    func didReceiveSettingsState(isAvailable: Bool)
    func didReceive(issues: [SwapSetupViewIssue])
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
    func showFeeInfo()
    func showRateInfo()
    func showSettings()
    func showRouteDetails()
    func selectMaxPayAmount()
    func depositInsufficientToken()
    func applyPoolTradeLimit()
}

protocol SwapSetupInteractorInputProtocol: SwapBaseInteractorInputProtocol {
    func setup()
    func update(receiveChainAsset: ChainAsset?)
    func update(payChainAsset: ChainAsset?)
    func update(feeChainAsset: ChainAsset?)
}

protocol SwapSetupInteractorOutputProtocol: SwapBaseInteractorOutputProtocol {
    func didReceiveCanPayFeeInPayAsset(_ value: Bool, chainAssetId: ChainAssetId)
    func didReceiveQuoteDataChanged()
}

protocol SwapSetupWireframeProtocol: SwapBaseWireframeProtocol,
    ShortTextInfoPresentable,
    RampPresentable,
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
        purchaseHadler: RampFlowManaging & RampDelegate,
        destinationChainAsset: ChainAsset,
        locale: Locale
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

    func popTopControllers(
        from view: ControllerBackedProtocol?,
        completion: @escaping () -> Void
    )
}

enum SwapSetupViewIssue: Equatable {
    case zeroBalance
    case insufficientBalance
    case minBalanceViolation(String)
    case noLiqudity
    case zeroReceiveAmount
    case poolTradeLimit(SwapPoolTradeLimitViewModel)
}

/// Which of the two amount fields an inline issue is about. Android's dialog is modal and so has no
/// field affinity to get wrong; rendering inline forces the choice, and getting it wrong points the
/// user at an input the message does not describe.
enum SwapAmountFieldSide {
    case pay
    case receive

    /// The field a cap measured in `direction` is about — the same field `applySuggestedAmount` fills
    /// and focuses, so the decoration, the copy and the tap can never point at different inputs.
    init(direction: AssetConversion.Direction) {
        self = switch direction {
        case .sell: .pay
        case .buy: .receive
        }
    }
}

/// Android shows this as a dialog on the user's tap. On the setup screen a failed quote is automatic —
/// it re-fires on every keystroke and every debounced reserve tick — so a modal there would pop while
/// the user types. It renders inline instead, in the same label `.noLiqudity` uses, with the tap-apply
/// as a button beneath the field it fills. The copy, the amount and the one-tap action are Android's.
struct SwapPoolTradeLimitViewModel: Equatable {
    let message: String

    /// `nil` where there is nothing for a button to fill in: an intermediate hop's cap, or a spent
    /// correction budget.
    let applyTitle: String?

    /// The field the message describes and the button fills: the pay field for a `.sell` cap, the
    /// receive field for a `.buy` one. It is the side the user typed into either way, so it is also
    /// where an intermediate hop's unactionable route message belongs.
    let side: SwapAmountFieldSide
}
