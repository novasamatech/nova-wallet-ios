import Foundation
import Foundation_iOS

final class MultisigOperationConfirmPresenter {
    weak var view: MultisigOperationConfirmViewProtocol?
    let wireframe: MultisigOperationConfirmWireframeProtocol
    let interactor: MultisigOperationConfirmInteractorInputProtocol
    let viewModelFactory: MultisigOperationConfirmViewModelFactoryProtocol
    let dataValidationFactory: MultisigDataValidatorFactoryProtocol
    let logger: LoggerProtocol

    let chain: ChainModel
    let multisigWallet: MetaAccountModel

    var signatories: [Multisig.Signatory]?
    var pendingOperation: Multisig.PendingOperationProxyModel?
    var balanceExistence: AssetBalanceExistence?
    var signatoryBalance: AssetBalance?
    var fee: ExtrinsicFeeProtocol?
    var utilityAssetPriceData: PriceData?
    var transferAssetPriceData: PriceData?

    var multisigContext: DelegatedAccount.MultisigAccountModel? {
        multisigWallet.getMultisig(for: chain)
    }

    init(
        interactor: MultisigOperationConfirmInteractorInputProtocol,
        wireframe: MultisigOperationConfirmWireframeProtocol,
        viewModelFactory: MultisigOperationConfirmViewModelFactoryProtocol,
        dataValidationFactory: MultisigDataValidatorFactoryProtocol,
        chain: ChainModel,
        multisigWallet: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.dataValidationFactory = dataValidationFactory
        self.chain = chain
        self.multisigWallet = multisigWallet
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension MultisigOperationConfirmPresenter {
    func provideViewModel() {
        guard
            let pendingOperation,
            let signatories,
            let chainAsset = chain.utilityChainAsset()
        else { return }

        let params = MultisigOperationConfirmViewModelParams(
            pendingOperation: pendingOperation,
            chain: chain,
            multisigWallet: multisigWallet,
            signatories: signatories,
            fee: fee,
            chainAsset: chainAsset,
            utilityAssetPrice: utilityAssetPriceData,
            transferAssetPrice: transferAssetPriceData,
            confirmClosure: { [weak self] in
                self?.doConfirm()
            },
            callDataAddClosure: {
                [weak self] in

                self?.wireframe.showAddCallData(
                    from: self?.view,
                    for: pendingOperation.operation
                )
            }
        )

        let viewModel = viewModelFactory.createViewModel(
            params: params,
            locale: selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }

    func provideFeeViewModel() {
        guard let chainAsset = chain.utilityChainAsset() else { return }

        let viewModel = viewModelFactory.createFeeFieldViewModel(
            fee: fee,
            feeAsset: chainAsset,
            assetPrice: utilityAssetPriceData,
            locale: selectedLocale
        )

        view?.didReceive(feeViewModel: viewModel)
    }

    func provideAmountViewModel() {
        guard let definition = pendingOperation?.formattedModel?.definition else {
            return
        }

        let viewModel = viewModelFactory.createAmountViewModel(
            from: definition,
            priceData: transferAssetPriceData,
            locale: selectedLocale
        )

        view?.didReceive(amount: viewModel)
    }

    func presentOptions(for accountId: AccountId) {
        guard let address = try? accountId.toAddress(using: chain.chainFormat) else {
            return
        }

        presentOptions(for: address)
    }

    func presentOptions(for address: AccountAddress) {
        guard let view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }

    func showSuccessApprove(with model: ExtrinsicSubmittedModel) {
        guard
            let multisigContext,
            let definition = pendingOperation?.operation.multisigDefinition
        else { return }

        let text = if multisigContext.threshold - definition.approvals.count > 1 {
            R.string.localizable.commonTransactionSigned(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            R.string.localizable.commonTransactionSignedAndExecuted(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        wireframe.presentExtrinsicSubmission(
            from: view,
            params: .init(
                title: .preferred(text),
                sender: model.sender,
                preferredCompletionAction: .dismiss
            )
        )
    }

    func showSuccessReject(with model: ExtrinsicSubmittedModel) {
        let text = R.string.localizable.commonTransactionRejected(preferredLanguages: selectedLocale.rLanguages)

        wireframe.presentExtrinsicSubmission(
            from: view,
            params: .init(
                title: .preferred(text),
                sender: model.sender,
                preferredCompletionAction: .dismiss
            )
        )
    }

    func doConfirm() {
        guard let utilityChainAsset = chain.utilityChainAsset() else {
            return
        }

        let signatoryName = signatories?.findSignatory(
            for: multisigWallet,
            chain: chain
        )?.localAccount?.chainAccount.name

        DataValidationRunner(validators: [
            dataValidationFactory.has(
                fee: fee,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.refreshFee()
            },
            dataValidationFactory.canPayFee(
                params: MultisigFeeValidationParams(
                    balance: signatoryBalance?.transferable,
                    fee: fee,
                    signatoryName: signatoryName ?? "",
                    assetInfo: utilityChainAsset.assetDisplayInfo
                ),
                locale: selectedLocale
            ),
            dataValidationFactory.notViolatingMinBalancePaying(
                fee: fee,
                total: signatoryBalance?.balanceCountingEd,
                minBalance: balanceExistence?.minBalance,
                asset: utilityChainAsset.assetDisplayInfo,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.view?.didReceive(loading: true)
            self?.interactor.confirm()
        }
    }
}

// MARK: - MultisigOperationConfirmPresenterProtocol

extension MultisigOperationConfirmPresenter: MultisigOperationConfirmPresenterProtocol {
    func actionShowSender() {
        guard let multisigContext else {
            return
        }

        presentOptions(for: multisigContext.accountId)
    }

    func actionShowRecipient() {
        guard case let .transfer(transfer) = pendingOperation?.formattedModel?.definition else {
            return
        }

        presentOptions(for: transfer.account.accountId)
    }

    func actionShowDelegated() {
        guard let delegatedAccount = pendingOperation?.formattedModel?.delegatedAccount else {
            return
        }

        presentOptions(for: delegatedAccount.accountId)
    }

    func actionFullDetails() {
        guard let pendingOperation else { return }

        wireframe.showFullDetails(
            from: view,
            for: pendingOperation
        )
    }

    func actionShowCurrentSignatory() {
        guard let multisigContext else {
            return
        }

        presentOptions(for: multisigContext.signatory)
    }

    func actionShowSignatory(with identifier: String) {
        presentOptions(for: identifier)
    }

    func setup() {
        interactor.setup()
    }
}

// MARK: - MultisigOperationConfirmInteractorOutputProtocol

extension MultisigOperationConfirmPresenter: MultisigOperationConfirmInteractorOutputProtocol {
    func didReceiveOperation(_ operation: Multisig.PendingOperationProxyModel?) {
        guard let operation else {
            return
        }

        pendingOperation = operation

        provideViewModel()
    }

    func didReceiveSignatories(_ signatories: [Multisig.Signatory]) {
        self.signatories = signatories

        provideViewModel()
    }

    func didReceiveAssetBalanceExistense(_ existense: AssetBalanceExistence) {
        balanceExistence = existense

        provideViewModel()
    }

    func didReceiveSignatoryBalance(_ assetBalance: AssetBalance?) {
        signatoryBalance = assetBalance

        provideViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        self.fee = fee

        provideFeeViewModel()
    }

    func didReceiveUtilityAssetPrice(_ priceData: PriceData?) {
        utilityAssetPriceData = priceData

        provideFeeViewModel()
    }

    func didReceiveTransferAssetPrice(_ priceData: PriceData?) {
        transferAssetPriceData = priceData

        provideFeeViewModel()
    }

    func didReceiveError(_ error: MultisigOperationConfirmInteractorError) {
        switch error {
        case .signatoriesFetchFailed, .callProcessingFailed, .balanceInfoFailed:
            logger.error("Unexpected error: \(error)")
        case let .feeError(internalError):
            logger.error("Fee error: \(internalError)")

            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshFee()
            }
        case let .submissionError(internalError):
            view?.didReceive(loading: false)

            logger.error("Confirmation error: \(internalError)")

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                internalError,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        case .noOperationExists:
            view?.didReceive(loading: false)
            wireframe.presentOperationNotExist(from: view, locale: selectedLocale)
        }
    }

    func didCompleteSubmission(
        with model: ExtrinsicSubmittedModel,
        submissionType: MultisigSubmissionType
    ) {
        view?.didReceive(loading: false)

        switch submissionType {
        case .approve:
            showSuccessApprove(with: model)
        case .reject:
            showSuccessReject(with: model)
        }
    }
}

// MARK: Localizable

extension MultisigOperationConfirmPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }
    }
}
