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
    func changeYourWalletsViewState(_ state: YourWalletsControl.State)
    func didReceiveWeb3NameRecipient(viewModel: LoadableViewModelState<Web3NameReceipientView.Model>)
    func didReceiveRecipientInputState(focused: Bool, empty: Bool?)
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
    func didTapOnYourWallets()
    func showWeb3NameRecipient()
    func complete(recipient: String)
}

protocol TransferSetupInteractorIntputProtocol: AnyObject {
    func setup(destinationChainAsset: ChainAsset)
    func destinationChainAssetDidChanged(_ chainAsset: ChainAsset)
    func search(web3Name: String)
}

protocol TransferSetupInteractorOutputProtocol: AnyObject {
    func didReceiveAvailableXcm(destinations: [ChainAsset], xcmTransfers: XcmTransfers?)
    func didReceive(error: Error)
    func didReceive(metaChainAccountResponses: [MetaAccountChainResponse])
    func didReceive(recipients: [Web3TransferRecipient], for name: String)
}

protocol TransferSetupWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable,
    Web3NameAddressListPresentable {
    func showDestinationChainSelection(
        from view: TransferSetupViewProtocol?,
        selectionState: CrossChainDestinationSelectionState,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    )

    func showRecepientScan(from view: TransferSetupViewProtocol?, delegate: AddressScanDelegate)

    func hideRecepientScan(from view: TransferSetupViewProtocol?)

    func showYourWallets(
        from view: TransferSetupViewProtocol?,
        accounts: [MetaAccountChainResponse],
        address: AccountAddress?,
        delegate: YourWalletsDelegate
    )

    func hideYourWallets(from view: TransferSetupViewProtocol?)
}
