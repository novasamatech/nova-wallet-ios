import Foundation

protocol MultisigOperationConfirmViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: MultisigOperationConfirmViewModel)
    func didReceive(feeViewModel: MultisigOperationConfirmViewModel.SectionField<BalanceViewModelProtocol?>)
    func didReceive(loading: Bool)
}

protocol MultisigOperationConfirmPresenterProtocol: AnyObject {
    func setup()
    func actionShowSender()
    func actionShowReceiver()
    func actionShowDelegate()
    func actionShowCurrentSignatory()
    func actionShowSignatory(with identifier: String)
}

protocol MultisigOperationConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func confirm()
}

protocol MultisigOperationConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveOperation(_ operation: Multisig.PendingOperation?)
    func didReceiveSignatories(_ signatories: [Multisig.Signatory])
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveAssetBalanceExistense(_ existense: AssetBalanceExistence)
    func didReceiveSignatoryBalance(_ assetBalance: AssetBalance?)
    func didReceivePriceData(_ priceData: PriceData?)
    func didCompleteSubmission(with submissionType: MultisigSubmissionType)
    func didReceiveError(_ error: MultisigOperationConfirmInteractorError)
}

protocol MultisigOperationConfirmWireframeProtocol: AddressOptionsPresentable, ModalAlertPresenting {
    func showAddCallData(
        from view: ControllerBackedProtocol?,
        for operation: Multisig.PendingOperation
    )
    func close(from view: ControllerBackedProtocol?)
}

enum MultisigOperationConfirmInteractorError {
    case signatoriesFetchFailed(Error)
    case callProcessingFailed(Error)
    case balanceInfoFailed(Error)
    case feeError(Error)
    case submissionError(Error)
}
