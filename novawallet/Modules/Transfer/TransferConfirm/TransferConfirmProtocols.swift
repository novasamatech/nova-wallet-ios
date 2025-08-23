import BigInt

protocol TransferConfirmCommonViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveOriginNetwork(viewModel: NetworkViewModel)
    func didReceiveSender(viewModel: DisplayAddressViewModel)
    func didReceiveRecepient(viewModel: DisplayAddressViewModel)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveOriginFee(viewModel: BalanceViewModelProtocol?)
}

protocol TransferConfirmOnChainViewProtocol: TransferConfirmCommonViewProtocol {}

protocol TransferConfirmCrossChainViewProtocol: TransferConfirmCommonViewProtocol {
    func didReceiveDestinationNetwork(viewModel: NetworkViewModel)
    func didReceiveCrossChainFee(viewModel: BalanceViewModelProtocol?)
}

protocol TransferConfirmPresenterProtocol: AnyObject {
    func setup()
    func submit()
    func showSenderActions()
    func showRecepientActions()
}

protocol TransferConfirmOnChainInteractorInputProtocol: OnChainTransferSetupInteractorInputProtocol {
    func submit(amount: OnChainTransferAmount<BigUInt>, recepient: AccountAddress, lastFee: BigUInt?)
}

protocol TransferConfirmCrossChainInteractorInputProtocol: CrossChainTransferSetupInteractorInputProtocol {
    func submit(amount: BigUInt, recepient: AccountAddress, originFee: ExtrinsicFeeProtocol?)
}

protocol TransferConfirmOnChainInteractorOutputProtocol: OnChainTransferSetupInteractorOutputProtocol {
    func didCompleteSubmition(by sender: ExtrinsicSenderResolution?)
}

protocol TransferConfirmCrossChainInteractorOutputProtocol: CrossChainTransferSetupInteractorOutputProtocol {
    func didCompleteSubmition(by sender: ExtrinsicSenderResolution)
}

protocol TransferConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    TransferErrorPresentable, AddressOptionsPresentable, FeeRetryable, CommonRetryable, MessageSheetPresentable,
    ModalAlertPresenting, ExtrinsicSigningErrorHandling, ExtrinsicSubmissionPresenting {}
