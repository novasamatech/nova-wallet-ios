import BigInt
import Foundation

protocol GiftTransferSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveTransferableBalance(viewModel: String)
    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceive(issues: [GiftSetupViewIssue])
    func didReceive(title: GiftSetupNetworkContainerViewModel)
}

protocol GiftTransferSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for amount: OnChainTransferAmount<BigUInt>)
}

protocol GiftTransferSetupInteractorOutputProtocol: OnChainTransferSetupInteractorOutputProtocol {
    func didReceiveFee(description: GiftFeeDescription)
}

protocol GiftTransferSetupPresenterProtocol: AnyObject {
    func setup()
    func updateAmount(_ newValue: Decimal?)
    func proceed()
    func getTokens()
}

protocol GiftTransferSetupWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    TransferErrorPresentable,
    EvmValidationErrorPresentable,
    PhishingErrorPresentable,
    RampPresentable,
    FeeRetryable {
    func showConfirmation(
        from view: GiftTransferSetupViewProtocol?,
        chainAsset: ChainAsset,
        sendingAmount: OnChainTransferAmount<Decimal>
    )
    func showGetTokenOptions(
        from view: ControllerBackedProtocol?,
        purchaseHadler: RampFlowManaging & RampDelegate,
        destinationChainAsset: ChainAsset,
        locale: Locale
    )
    func popTopControllers(
        from view: ControllerBackedProtocol?,
        completion: @escaping () -> Void
    )
}
