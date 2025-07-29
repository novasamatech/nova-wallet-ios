import Foundation

protocol MultisigOperationConfirmViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: MultisigOperationConfirmViewModel)
    func didReceive(amount: BalanceViewModelProtocol?)
    func didReceive(feeViewModel: MultisigOperationConfirmViewModel.SectionField<BalanceViewModelProtocol?>)
    func didReceive(loading: Bool)
}

protocol MultisigOperationConfirmPresenterProtocol: AnyObject {
    func setup()
    func actionShowSender()
    func actionShowRecipient()
    func actionShowDelegated()
    func actionShowCurrentSignatory()
    func actionShowSignatory(with identifier: String)
    func actionFullDetails()
}

protocol MultisigOperationConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func confirm()
    func refreshFee()
}

protocol MultisigOperationConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveOperation(_ operation: Multisig.PendingOperationProxyModel?)
    func didReceiveSignatories(_ signatories: [Multisig.Signatory])
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveAssetBalanceExistense(_ existense: AssetBalanceExistence)
    func didReceiveSignatoryBalance(_ assetBalance: AssetBalance?)
    func didReceiveUtilityAssetPrice(_ priceData: PriceData?)
    func didReceiveOperationAssetPrice(_ priceData: PriceData?)
    func didReceive(needsConfirmation: Bool)
    func didCompleteSubmission(
        with model: ExtrinsicSubmittedModel,
        submissionType: MultisigSubmissionType
    )

    func didReceiveError(_ error: MultisigOperationConfirmInteractorError)
}

protocol MultisigOperationConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable, MultisigErrorPresentable, ExtrinsicSigningErrorHandling,
    CommonRetryable, FeeRetryable, MessageSheetPresentable,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {
    func showAddCallData(
        from view: ControllerBackedProtocol?,
        for operation: Multisig.PendingOperation
    )
    func showFullDetails(
        from view: ControllerBackedProtocol?,
        for operation: Multisig.PendingOperationProxyModel
    )
    func showConfirmOperationSheet(
        from view: ControllerBackedProtocol?,
        multisigAccountId: MetaAccountModel.Id,
        depositorAccount: MetaChainAccountResponse,
        completionClosure: @escaping MessageSheetCallback
    )
    func close(from view: ControllerBackedProtocol?)
}

enum MultisigOperationConfirmInteractorError {
    case signatoriesFetchFailed(Error)
    case callProcessingFailed(Error)
    case balanceInfoFailed(Error)
    case feeError(Error)
    case submissionError(Error)
    case noOperationExists
}
