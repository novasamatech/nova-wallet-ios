import Foundation
import Foundation_iOS
import SubstrateSdk
import BigInt

final class TransferOnChainConfirmPresenter: OnChainTransferPresenter {
    weak var view: TransferConfirmOnChainViewProtocol?
    let wireframe: TransferConfirmWireframeProtocol
    let interactor: TransferConfirmOnChainInteractorInputProtocol

    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol

    let recepientAccountAddress: AccountAddress
    let wallet: MetaAccountModel
    let amount: OnChainTransferAmount<Decimal>

    private lazy var walletIconGenerator = NovaIconGenerator()
    let transferCompletion: TransferCompletionClosure?

    init(
        interactor: TransferConfirmOnChainInteractorInputProtocol,
        wireframe: TransferConfirmWireframeProtocol,
        wallet: MetaAccountModel,
        recepient: AccountAddress,
        amount: OnChainTransferAmount<Decimal>,
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        feeAsset: ChainAsset,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        senderAccountAddress: AccountAddress,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        transferCompletion: TransferCompletionClosure?,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.wallet = wallet
        recepientAccountAddress = recepient
        self.amount = amount
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.transferCompletion = transferCompletion
        super.init(
            chainAsset: chainAsset,
            feeAsset: feeAsset,
            networkViewModelFactory: networkViewModelFactory,
            sendingBalanceViewModelFactory: sendingBalanceViewModelFactory,
            utilityBalanceViewModelFactory: utilityBalanceViewModelFactory,
            senderAccountAddress: senderAccountAddress,
            dataValidatingFactory: dataValidatingFactory,
            logger: logger
        )

        self.localizationManager = localizationManager
    }

    func getRecepientAccountId() -> AccountId? {
        try? recepientAccountAddress.toAccountId(using: chainAsset.chain.chainFormat)
    }

    private func provideNetworkViewModel() {
        let viewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
        view?.didReceiveOriginNetwork(viewModel: viewModel)
    }

    private func provideWalletViewModel() {
        let name = wallet.name

        let icon = wallet.walletIdenticonData().flatMap { try? walletIconGenerator.generateFromAccountId($0) }
        let iconViewModel = icon.map { DrawableIconViewModel(icon: $0) }
        let viewModel = StackCellViewModel(details: name, imageViewModel: iconViewModel)
        view?.didReceiveWallet(viewModel: viewModel)
    }

    private func provideSenderViewModel() {
        let displayAddress = DisplayAddress(address: senderAccountAddress, username: "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveSender(viewModel: viewModel)
    }

    private func provideRecepientViewModel() {
        let displayAddress = DisplayAddress(address: recepientAccountAddress, username: "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveRecepient(viewModel: viewModel)
    }

    private func provideNetworkFeeViewModel() {
        if let fee = fee {
            let assetInfo = feeAsset.asset.displayInfo

            let feeDecimal = Decimal.fromSubstrateAmount(
                fee.value.amount,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let viewModelFactory = sendingAssetFeeSelected
                ? sendingBalanceViewModelFactory
                : utilityBalanceViewModelFactory ?? sendingBalanceViewModelFactory

            let priceData = sendingAssetFeeSelected
                ? sendingAssetPrice
                : utilityAssetPrice

            let balanceViewModel = viewModelFactory.balanceFromPrice(
                feeDecimal,
                priceData: priceData
            ).value(for: selectedLocale)

            view?.didReceiveOriginFee(viewModel: balanceViewModel)
        } else {
            view?.didReceiveOriginFee(viewModel: nil)
        }
    }

    private func provideAmountViewModel() {
        let viewModel = sendingBalanceViewModelFactory.spendingAmountFromPrice(
            amount.value,
            priceData: sendingAssetPrice
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func presentOptions(for address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    // MARK: Subsclass

    override func refreshFee() {
        let assetInfo = chainAsset.assetDisplayInfo

        guard let amountInPlank = amount.flatMap({ $0.toSubstrateAmount(precision: assetInfo.assetPrecision) }) else {
            return
        }

        interactor.estimateFee(for: amountInPlank, recepient: getRecepientAccountId())
    }

    override func askFeeRetry() {
        wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.refreshFee()
        }
    }

    override func didReceiveFee(result: Result<FeeOutputModel, Error>) {
        super.didReceiveFee(result: result)

        if case .success = result {
            provideNetworkFeeViewModel()
        }
    }

    override func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        super.didReceiveSendingAssetPrice(priceData)

        if isUtilityTransfer {
            provideNetworkFeeViewModel()
        }

        provideAmountViewModel()
    }

    override func didReceiveUtilityAssetPrice(_ priceData: PriceData?) {
        super.didReceiveUtilityAssetPrice(priceData)

        provideNetworkFeeViewModel()
    }

    override func didCompleteSetup() {
        super.didCompleteSetup()

        refreshFee()

        interactor.change(recepient: getRecepientAccountId())
    }

    override func didReceiveError(_ error: Error) {
        super.didReceiveError(error)

        view?.didStopLoading()

        wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
            error,
            view: view,
            closeAction: .dismiss,
            locale: selectedLocale,
            completionClosure: nil
        )
    }
}

extension TransferOnChainConfirmPresenter: TransferConfirmPresenterProtocol {
    func setup() {
        provideAmountViewModel()
        provideNetworkViewModel()
        provideWalletViewModel()
        provideSenderViewModel()
        provideNetworkFeeViewModel()
        provideRecepientViewModel()

        interactor.setup()
    }

    func submit() {
        let assetPrecision = chainAsset.assetDisplayInfo.assetPrecision
        guard
            let amountInPlank = amount.flatMap({ $0.toSubstrateAmount(precision: assetPrecision) }),
            let utilityAsset = chainAsset.chain.utilityAsset() else {
            return
        }

        let validators: [DataValidating] = baseValidators(
            for: amount.value,
            recepientAddress: recepientAccountAddress,
            feeAssetInfo: feeAsset.assetDisplayInfo,
            view: view,
            selectedLocale: selectedLocale
        )

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.view?.didStartLoading()

            strongSelf.interactor.submit(
                amount: amountInPlank,
                recepient: strongSelf.recepientAccountAddress,
                lastFee: strongSelf.fee?.value.amount
            )
        }
    }

    func showSenderActions() {
        presentOptions(for: senderAccountAddress)
    }

    func showRecepientActions() {
        presentOptions(for: recepientAccountAddress)
    }
}

extension TransferOnChainConfirmPresenter: TransferConfirmOnChainInteractorOutputProtocol {
    func didCompleteSubmition(by sender: ExtrinsicSenderResolution?) {
        view?.didStopLoading()

        // Note: that transferCompletion is not called for delayed transfers
        wireframe.presentExtrinsicSubmission(
            from: view,
            sender: sender,
            completionAction: .dismissWithPostNavigation { [transferCompletion, chainAsset] in
                transferCompletion?(chainAsset)
            },
            locale: selectedLocale
        )
    }
}

extension TransferOnChainConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideNetworkFeeViewModel()
        }
    }
}
