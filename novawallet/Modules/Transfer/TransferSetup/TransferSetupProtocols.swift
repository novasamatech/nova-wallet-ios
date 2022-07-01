import BigInt
import CommonWallet
import SoraFoundation

protocol TransferSetupChildViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveTransferableBalance(viewModel: String)
    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveOriginFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveCrossChainFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceiveAccountState(viewModel: AccountFieldStateViewModel)
    func didReceiveAccountInput(viewModel: InputViewModelProtocol)
    func didReceiveCanSendMySelf(_ canSendMySelf: Bool)
}

protocol TransferSetupViewProtocol: TransferSetupChildViewProtocol {
    func didReceiveOriginChain(_ originChain: ChainAssetViewModel, destinationChain: NetworkViewModel?)
    func didCompleteDestinationSelection()
    func didSwitchCrossChain()
    func didSwitchOnChain()
}

protocol TransferSetupCommonPresenterProtocol: AnyObject {
    func setup()
    func updateRecepient(partialAddress: String)
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func proceed()
}

protocol TransferSetupChildPresenterProtocol: TransferSetupCommonPresenterProtocol {
    var inputState: TransferSetupInputState { get }

    func changeRecepient(address: String)
}

protocol TransferSetupPresenterProtocol: TransferSetupCommonPresenterProtocol {
    func changeDestinationChain()
    func scanRecepientCode()
    func applyMyselfRecepient()
}

protocol TransferSetupInteractorIntputProtocol: AnyObject {
    func setup()
}

protocol TransferSetupInteractorOutputProtocol: AnyObject {
    func didReceiveAvailableXcm(destinations: [ChainAsset], xcmTransfers: XcmTransfers?)
    func didReceive(error: Error)
}

protocol TransferSetupWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showDestinationChainSelection(
        from view: TransferSetupViewProtocol?,
        selectionState: CrossChainDestinationSelectionState,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    )

    func showRecepientScan(from view: TransferSetupViewProtocol?, delegate: TransferScanDelegate)

    func hideRecepientScan(from view: TransferSetupViewProtocol?)
}
