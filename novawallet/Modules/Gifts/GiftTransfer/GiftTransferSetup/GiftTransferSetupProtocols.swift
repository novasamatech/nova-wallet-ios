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

protocol GiftTransferSetupInteractorOutputProtocol: OnChainTransferSetupInteractorOutputProtocol {}

protocol GiftTransferSetupPresenterProtocol: AnyObject {
    func setup()
    func updateAmount(_ newValue: Decimal?)
    func proceed()
}

protocol GiftTransferSetupWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    TransferErrorPresentable,
    PhishingErrorPresentable,
    FeeRetryable {
    func showConfirmation(
        from view: GiftTransferSetupViewProtocol?,
        chainAsset: ChainAsset,
        sendingAmount: OnChainTransferAmount<Decimal>
    )
}
