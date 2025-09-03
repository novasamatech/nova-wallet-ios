import Foundation
import BigInt
import Foundation_iOS

protocol TransferSetupChildViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveTransferableBalance(viewModel: String)
    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveOriginFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>)
    func didReceiveCrossChainFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceiveAccountState(viewModel: AccountFieldStateViewModel)
    func didReceiveAccountInput(viewModel: InputViewModelProtocol)
    func didReceiveCanSendMySelf(_ canSendMySelf: Bool)
}

protocol TransferSetupViewProtocol: TransferSetupChildViewProtocol {
    func didReceiveSelection(viewModel: TransferNetworkContainerViewModel)
    func didCompleteChainSelection()
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
    func changeFeeAsset(to chainAsset: ChainAsset?)
    func getFeeAsset() -> ChainAsset?
}

extension TransferSetupChildPresenterProtocol {
    func changeFeeAsset(to _: ChainAsset?) {}
    func getFeeAsset() -> ChainAsset? { nil }
}

protocol TransferSetupPresenterProtocol: TransferSetupCommonPresenterProtocol {
    func selectChain()
    func scanRecepientCode()
    func applyMyselfRecepient()
    func didTapOnYourWallets()
    func editFeeAsset()
    func showWeb3NameRecipient()
    func complete(recipient: String)
}

protocol TransferSetupInteractorIntputProtocol: AnyObject {
    func setup(peerChainAsset: ChainAsset)
    func peerChainAssetDidChanged(_ chainAsset: ChainAsset)
    func search(web3Name: String)
}

protocol TransferSetupInteractorOutputProtocol: AnyObject {
    func didReceiveAvailableXcm(peerChainAssets: [ChainAsset], xcmTransfers: XcmTransfers?)
    func didReceive(error: Error)
    func didReceive(metaChainAccountResponses: [MetaAccountChainResponse])
    func didReceive(recipients: [Web3TransferRecipient], for name: String)
}

protocol TransferSetupWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    AddressOptionsPresentable,
    Web3NameAddressListPresentable,
    YourWalletsPresentable,
    ScanAddressPresentable,
    FeeAssetSelectionPresentable {
    func showDestinationChainSelection(
        from view: TransferSetupViewProtocol?,
        selectionState: CrossChainDestinationSelectionState,
        delegate: ModalPickerViewControllerDelegate
    )

    func showOriginChainSelection(
        from view: TransferSetupViewProtocol?,
        chainAsset: ChainAsset,
        selectionState: CrossChainOriginSelectionState,
        delegate: ModalPickerViewControllerDelegate
    )

    func checkDismissing(view: TransferSetupViewProtocol?) -> Bool
}
