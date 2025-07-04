import Foundation
import Foundation_iOS

final class MultisigOperationConfirmPresenter {
    weak var view: MultisigOperationConfirmViewProtocol?
    let wireframe: MultisigOperationConfirmWireframeProtocol
    let interactor: MultisigOperationConfirmInteractorInputProtocol
    let viewModelFactory: MultisigOperationConfirmViewModelFactoryProtocol
    let logger: LoggerProtocol

    let chain: ChainModel
    let multisigWallet: MetaAccountModel

    var signatories: [Multisig.Signatory]?
    var pendingOperation: Multisig.PendingOperationProxyModel?
    var balanceExistence: AssetBalanceExistence?
    var signatoryBalance: AssetBalance?
    var signatoryWallet: MetaAccountModel?
    var fee: ExtrinsicFeeProtocol?
    var priceData: PriceData?

    var multisigContext: DelegatedAccount.MultisigAccountModel? {
        multisigWallet.multisigAccount?.multisig
    }

    init(
        interactor: MultisigOperationConfirmInteractorInputProtocol,
        wireframe: MultisigOperationConfirmWireframeProtocol,
        viewModelFactory: MultisigOperationConfirmViewModelFactoryProtocol,
        chain: ChainModel,
        multisigWallet: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
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
            feeAsset: chainAsset,
            assetPrice: priceData,
            confirmClosure: { [weak self] in
                self?.view?.didReceive(loading: true)
                self?.interactor.confirm()
            },
            callDataAddClosure: { [weak self] in self?.wireframe.showAddCallData(from: self?.view) }
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
            assetPrice: priceData,
            locale: selectedLocale
        )

        view?.didReceive(feeViewModel: viewModel)
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

    func showSuccessApprove() {
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

        wireframe.presentSuccessNotification(
            text,
            from: view
        ) { [weak self] in
            self?.wireframe.close(from: self?.view)
        }
    }

    func showSuccessReject() {
        wireframe.presentSuccessNotification(
            R.string.localizable.commonTransactionRejected(preferredLanguages: selectedLocale.rLanguages),
            from: view
        ) { [weak self] in
            self?.wireframe.close(from: self?.view)
        }
    }
}

extension MultisigOperationConfirmPresenter: MultisigOperationConfirmPresenterProtocol {
    func actionShowSender() {
        guard
            let multisigContext = multisigWallet.multisigAccount?.multisig,
            let address = try? multisigContext.accountId.toAddress(using: chain.chainFormat)
        else {
            return
        }

        presentOptions(for: address)
    }

    func actionShowReceiver() {
        // TODO: Implement when call formatting is available
    }

    func actionShowDelegate() {
        // TODO: Implement when call formatting is available
    }

    func actionShowCurrentSignatory() {
        guard
            let multisigContext = multisigWallet.multisigAccount?.multisig,
            let address = try? multisigContext.signatory.toAddress(using: chain.chainFormat)
        else {
            return
        }

        presentOptions(for: address)
    }

    func actionShowSignatory(with identifier: String) {
        presentOptions(for: identifier)
    }

    func setup() {
        interactor.setup()
    }
}

extension MultisigOperationConfirmPresenter: MultisigOperationConfirmInteractorOutputProtocol {
    func didReceiveOperation(_ operation: Multisig.PendingOperationProxyModel?) {
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

    func didReceivePriceData(_ priceData: PriceData?) {
        self.priceData = priceData

        provideFeeViewModel()
    }

    func didReceiveError(_ error: MultisigOperationConfirmInteractorError) {
        view?.didReceive(loading: false)
        logger.error("Error: \(error)")
    }

    func didCompleteSubmission(with submissionType: MultisigSubmissionType) {
        view?.didReceive(loading: false)

        switch submissionType {
        case .approve:
            showSuccessApprove()
        case .reject:
            showSuccessReject()
        }
    }
}

// MARK: Localizable

extension MultisigOperationConfirmPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }
    }
}
