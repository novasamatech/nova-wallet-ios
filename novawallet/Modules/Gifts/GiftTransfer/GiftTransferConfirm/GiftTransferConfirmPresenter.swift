import Foundation
import Foundation_iOS
import SubstrateSdk
import BigInt

final class GiftTransferConfirmPresenter: GiftTransferPresenter {
    weak var view: GiftTransferConfirmViewProtocol?
    let wireframe: GiftTransferConfirmWireframeProtocol
    let interactor: GiftTransferConfirmInteractorInputProtocol

    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol

    let wallet: MetaAccountModel
    let amount: OnChainTransferAmount<Decimal>

    private lazy var walletIconGenerator = NovaIconGenerator()
    let transferCompletion: TransferCompletionClosure?

    init(
        interactor: GiftTransferConfirmInteractorInputProtocol,
        wireframe: GiftTransferConfirmWireframeProtocol,
        wallet: MetaAccountModel,
        amount: OnChainTransferAmount<Decimal>,
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        senderAccountAddress: AccountAddress,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        transferCompletion: TransferCompletionClosure?,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.wallet = wallet
        self.amount = amount
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.transferCompletion = transferCompletion

        super.init(
            chainAsset: chainAsset,
            networkViewModelFactory: networkViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            senderAccountAddress: senderAccountAddress,
            dataValidatingFactory: dataValidatingFactory,
            logger: logger
        )

        self.localizationManager = localizationManager
    }

    // MARK: - Override

    override func refreshFee() {
        let assetInfo = chainAsset.assetDisplayInfo

        guard let amountInPlank = amount.flatMap(
            { $0.toSubstrateAmount(precision: assetInfo.assetPrecision) }
        ) else { return }

        interactor.estimateFee(for: amountInPlank)
    }

    override func askFeeRetry() {
        wireframe.presentFeeStatus(
            on: view,
            locale: selectedLocale
        ) { [weak self] in
            self?.refreshFee()
        }
    }

    override func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        super.didReceiveSendingAssetPrice(priceData)

        provideFeeViewModel()
        provideAmountViewModel()
    }

    override func didReceiveFee(description: GiftFeeDescription) {
        super.didReceiveFee(description: description)

        provideFeeViewModel()
    }

    override func didCompleteSetup() {
        super.didCompleteSetup()

        refreshFee()
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

// MARK: - Private

private extension GiftTransferConfirmPresenter {
    func provideNetworkViewModel() {
        let viewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
        view?.didReceiveNetwork(viewModel: viewModel)
    }

    func provideWalletViewModel() {
        let name = wallet.name

        let icon = wallet.walletIdenticonData().flatMap { try? walletIconGenerator.generateFromAccountId($0) }
        let iconViewModel = icon.map { DrawableIconViewModel(icon: $0) }
        let viewModel = StackCellViewModel(details: name, imageViewModel: iconViewModel)
        view?.didReceiveWallet(viewModel: viewModel)
    }

    func provideSenderViewModel() {
        let displayAddress = DisplayAddress(address: senderAccountAddress, username: "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveSender(viewModel: viewModel)
    }

    func provideFeeViewModel() {
        guard let feeDescription else {
            view?.didReceiveNetworkFee(viewModel: nil)
            view?.didReceiveClaimFee(viewModel: nil)
            return
        }

        let createFeeModel = createFeeViewModel(for: feeDescription.createFee.amount)
        let claimFeeModel = createFeeViewModel(for: feeDescription.claimFee.amount)

        view?.didReceiveNetworkFee(viewModel: createFeeModel)
        view?.didReceiveClaimFee(viewModel: claimFeeModel)
    }

    func provideAmountViewModel() {
        let spendingAmountViewModel = balanceViewModelFactory.spendingAmountFromPrice(
            amount.value,
            priceData: assetPrice
        ).value(for: selectedLocale)

        let giftAmountViewModel = balanceViewModelFactory.lockingAmountFromPrice(
            amount.value,
            priceData: assetPrice
        ).value(for: selectedLocale)

        view?.didReceiveSpendingAmount(viewModel: spendingAmountViewModel)
        view?.didReceiveGiftAmount(viewModel: giftAmountViewModel)
    }

    func presentOptions(for address: AccountAddress) {
        guard let view else { return }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func createFeeViewModel(for feeAmount: BigUInt) -> BalanceViewModelProtocol {
        let assetInfo = chainAsset.asset.displayInfo

        let feeDecimal = Decimal.fromSubstrateAmount(
            feeAmount,
            precision: assetInfo.assetPrecision
        ) ?? 0.0

        return balanceViewModelFactory.balanceFromPrice(
            feeDecimal,
            priceData: assetPrice
        ).value(for: selectedLocale)
    }
}

// MARK: - GiftTransferConfirmPresenterProtocol

extension GiftTransferConfirmPresenter: GiftTransferConfirmPresenterProtocol {
    func setup() {
        provideAmountViewModel()
        provideNetworkViewModel()
        provideWalletViewModel()
        provideSenderViewModel()
        provideFeeViewModel()

        interactor.setup()
    }

    func submit() {
        let assetPrecision = chainAsset.assetDisplayInfo.assetPrecision

        guard let amountInPlank = amount.flatMap(
            { $0.toSubstrateAmount(precision: assetPrecision) }
        ) else { return }

        let validators: [DataValidating] = baseValidators(
            for: amount.value,
            feeAssetInfo: chainAsset.assetDisplayInfo,
            view: view,
            selectedLocale: selectedLocale
        )

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            guard let self else { return }

            view?.didStartLoading()

            interactor.submit(
                amount: amountInPlank,
                lastFeeDescription: feeDescription
            )
        }
    }

    func showSenderActions() {
        presentOptions(for: senderAccountAddress)
    }
}

// MARK: - GiftTransferConfirmInteractorOutputProtocol

extension GiftTransferConfirmPresenter: GiftTransferConfirmInteractorOutputProtocol {
    func didCompleteSubmission(with resultData: GiftTransferSubmissionResult) {
        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(
            from: view,
            sender: resultData.sender,
            completionAction: .postNavigation { [weak self] in
                guard let self else { return }

                wireframe.showGiftShare(
                    from: view,
                    giftId: resultData.giftId,
                    chainAsset: chainAsset
                )
            },
            locale: selectedLocale
        )
    }
}

// MARK: - Localizable

extension GiftTransferConfirmPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }

        provideFeeViewModel()
    }
}
