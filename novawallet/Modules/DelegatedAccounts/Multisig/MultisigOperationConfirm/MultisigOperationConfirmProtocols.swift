protocol MultisigOperationConfirmViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: MultisigOperationConfirmViewModel)
    func didReceive(feeViewModel: MultisigOperationConfirmViewModel.SectionField<BalanceViewModelProtocol?>)
}

protocol MultisigOperationConfirmPresenterProtocol: AnyObject {
    func setup()
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
    func didCompleteSubmission()
    func didReceiveError(_ error: MultisigOperationConfirmInteractorError)
}

protocol MultisigOperationConfirmWireframeProtocol: AnyObject {
    func showAddCallData(from view: ControllerBackedProtocol?)
}

enum MultisigOperationConfirmInteractorError {
    case signatoriesFetchFailed(Error)
    case callProcessingFailed(Error)
    case balanceInfoFailed(Error)
    case feeError(Error)
    case submissionError(Error)
}
