import BigInt
import CommonWallet
import SoraFoundation

protocol TransferSetupChildViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveTransferableBalance(viewModel: String)
    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceiveAccountState(viewModel: AccountFieldStateViewModel)
    func didReceiveAccountInput(viewModel: InputViewModelProtocol)
}

protocol TransferSetupViewProtocol: TransferSetupChildViewProtocol {
    func didReceiveOriginChain(_ originChain: ChainAssetViewModel, destinationChain: NetworkViewModel?)
    func didCompleteDestinationSelection()
}

protocol TransferSetupCommonPresenterProtocol: AnyObject {
    func setup()
    func updateRecepient(partialAddress: String)
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func scanRecepientCode()
    func proceed()
}

protocol TransferSetupChildPresenterProtocol: TransferSetupCommonPresenterProtocol {
    var inputState: TransferSetupInputState { get }
}

protocol TransferSetupPresenterProtocol: TransferSetupCommonPresenterProtocol {
    func changeDestinationChain()
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
        context: AnyObject?,
        locale: Locale
    )
}
