protocol CardTopUpTransferSetupViewProtocol: TransferSetupViewProtocol {}

extension CardTopUpTransferSetupViewProtocol {
    func didSwitchCrossChain() {}
    func didSwitchOnChain() {}
    func changeYourWalletsViewState(_: YourWalletsControl.State) {}
    func didReceiveSelection(viewModel _: TransferNetworkContainerViewModel) {}
    func didCompleteChainSelection() {}
    func didReceiveCrossChainFee(viewModel _: BalanceViewModelProtocol?) {}
    func didReceiveCanSendMySelf(_: Bool) {}
    func didReceiveRecipientInputState(focused _: Bool, empty _: Bool?) {}
    func didReceiveWeb3NameRecipient(viewModel _: LoadableViewModelState<Web3NameReceipientView.Model>) {}
}
