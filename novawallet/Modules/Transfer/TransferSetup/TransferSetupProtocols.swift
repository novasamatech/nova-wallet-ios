import BigInt
import CommonWallet
import SoraFoundation

protocol TransferSetupViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveTransferableBalance(viewModel: String)
    func didReceiveChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceiveAccountState(viewModel: AccountFieldStateViewModel)
    func didReceiveAccountInput(viewModel: InputViewModelProtocol)
}

protocol TransferSetupChildPresenterProtocol: AnyObject {
    var inputState: TransferSetupInputState { get }

    func setup()
    func updateRecepient(partialAddress: String)
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func scanRecepientCode()
    func proceed()
}

protocol TransferSetupPresenterProtocol: AnyObject {
    func setup()
    func updateRecepient(partialAddress: String)
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func scanRecepientCode()
    func proceed()
}

protocol TransferSetupInteractorIntputProtocol: AnyObject {
    func setup()
}

protocol TransferSetupInteractorOutputProtocol: AnyObject {
    func didReceiveAvailableXcm(destinations: [ChainAsset], xcmTransfers: XcmTransfers?)
    func didReceive(error: Error)
}

protocol TransferSetupWireframeProtocol: AlertPresentable, ErrorPresentable {}
