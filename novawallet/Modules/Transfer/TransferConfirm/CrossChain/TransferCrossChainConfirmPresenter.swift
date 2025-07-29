import Foundation
import Foundation_iOS
import SubstrateSdk
import BigInt

final class TransferCrossChainConfirmPresenter: CrossChainTransferPresenter {
    weak var view: TransferConfirmCrossChainViewProtocol?
    let wireframe: TransferConfirmWireframeProtocol
    let interactor: TransferConfirmCrossChainInteractorInputProtocol

    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol

    let recepientAccountAddress: AccountAddress
    let wallet: MetaAccountModel
    let amount: Decimal

    private lazy var walletIconGenerator = NovaIconGenerator()
    let transferCompletion: TransferCompletionClosure?

    init(
        interactor: TransferConfirmCrossChainInteractorInputProtocol,
        wireframe: TransferConfirmWireframeProtocol,
        wallet: MetaAccountModel,
        recepient: AccountAddress,
        amount: Decimal,
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
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
            originChainAsset: originChainAsset,
            destinationChainAsset: destinationChainAsset,
            networkViewModelFactory: networkViewModelFactory,
            sendingBalanceViewModelFactory: sendingBalanceViewModelFactory,
            utilityBalanceViewModelFactory: utilityBalanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            logger: logger
        )

        self.localizationManager = localizationManager
    }

    func getRecepientAccountId() -> AccountId? {
        try? recepientAccountAddress.toAccountId(using: destinationChainAsset.chain.chainFormat)
    }

    private func provideOriginNetworkViewModel() {
        let viewModel = networkViewModelFactory.createViewModel(from: originChainAsset.chain)
        view?.didReceiveOriginNetwork(viewModel: viewModel)
    }

    private func provideDestinationNetworkViewModel() {
        let viewModel = networkViewModelFactory.createViewModel(from: destinationChainAsset.chain)
        view?.didReceiveDestinationNetwork(viewModel: viewModel)
    }

    private func provideWalletViewModel() {
        let name = wallet.name

        let icon = wallet.walletIdenticonData().flatMap { try? walletIconGenerator.generateFromAccountId($0) }
        let iconViewModel = icon.map { DrawableIconViewModel(icon: $0) }
        let viewModel = StackCellViewModel(details: name, imageViewModel: iconViewModel)
        view?.didReceiveWallet(viewModel: viewModel)
    }

    private func provideSenderViewModel() {
        guard let senderAddress = wallet.fetch(for: originChainAsset.chain.accountRequest())?.toAddress() else {
            return
        }

        let displayAddress = DisplayAddress(address: senderAddress, username: "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveSender(viewModel: viewModel)
    }

    private func provideRecepientViewModel() {
        let displayAddress = DisplayAddress(address: recepientAccountAddress, username: "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveRecepient(viewModel: viewModel)
    }

    private func provideOriginFeeViewModel() {
        let optAssetInfo = originChainAsset.chain.utilityAssets().first?.displayInfo
        if let fee = displayOriginFee, let assetInfo = optAssetInfo {
            let feeDecimal = Decimal.fromSubstrateAmount(
                fee,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let viewModelFactory = utilityBalanceViewModelFactory ?? sendingBalanceViewModelFactory
            let priceData = isOriginUtilityTransfer ? sendingAssetPrice : utilityAssetPrice

            let viewModel = viewModelFactory.balanceFromPrice(feeDecimal, priceData: priceData)
                .value(for: selectedLocale)

            view?.didReceiveOriginFee(viewModel: viewModel)
        } else {
            view?.didReceiveOriginFee(viewModel: nil)
        }
    }

    private func provideCrossChainFeeViewModel() {
        let assetInfo = originChainAsset.assetDisplayInfo
        if let fee = displayCrosschainFee {
            let feeDecimal = Decimal.fromSubstrateAmount(
                fee,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let viewModel = sendingBalanceViewModelFactory.balanceFromPrice(
                feeDecimal,
                priceData: sendingAssetPrice
            ).value(for: selectedLocale)

            view?.didReceiveCrossChainFee(viewModel: viewModel)

        } else {
            view?.didReceiveCrossChainFee(viewModel: nil)
        }
    }

    private func provideAmountViewModel() {
        let viewModel = sendingBalanceViewModelFactory.spendingAmountFromPrice(
            amount,
            priceData: sendingAssetPrice
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func presentOptions(for address: AccountAddress, chain: ChainModel) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }

    // MARK: Subsclass

    override func getSendingAmount() -> Decimal? {
        amount
    }

    override func refreshOriginFee() {
        let assetInfo = originChainAsset.assetDisplayInfo

        guard let amountValue = amount.toSubstrateAmount(precision: assetInfo.assetPrecision) else {
            return
        }

        interactor.estimateOriginFee(
            for: amountValue,
            recepient: getRecepientAccountId()
        )
    }

    override func refreshCrossChainFee() {
        let assetInfo = originChainAsset.assetDisplayInfo

        guard let amountValue = amount.toSubstrateAmount(precision: assetInfo.assetPrecision) else {
            return
        }

        interactor.estimateCrossChainFee(for: amountValue, recepient: getRecepientAccountId())
    }

    override func askOriginFeeRetry() {
        wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.refreshOriginFee()
        }
    }

    override func askCrossChainFeeRetry() {
        wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.refreshCrossChainFee()
        }
    }

    override func didReceiveOriginFee(result: Result<ExtrinsicFeeProtocol, Error>) {
        super.didReceiveOriginFee(result: result)

        if case .success = result {
            provideOriginFeeViewModel()
        }
    }

    override func didReceiveCrossChainFee(result: Result<XcmFeeModelProtocol, Error>) {
        super.didReceiveCrossChainFee(result: result)

        if case .success = result {
            provideOriginFeeViewModel()
            provideCrossChainFeeViewModel()
            refreshOriginFee()
        }
    }

    override func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        super.didReceiveSendingAssetPrice(priceData)

        if isOriginUtilityTransfer {
            provideOriginFeeViewModel()
        }

        provideCrossChainFeeViewModel()
        provideAmountViewModel()
    }

    override func didReceiveUtilityAssetPrice(_ priceData: PriceData?) {
        super.didReceiveUtilityAssetPrice(priceData)

        provideOriginFeeViewModel()
    }

    override func didCompleteSetup(result: Result<Void, Error>) {
        super.didCompleteSetup(result: result)

        switch result {
        case .success:
            interactor.change(recepient: getRecepientAccountId())

            refreshCrossChainFee()
        case let .failure(error):
            logger?.error("Setup failed: \(error)")

            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.setup()
            }
        }
    }

    override func didReceiveError(_ error: Error) {
        super.didReceiveError(error)

        view?.didStopLoading()

        let isHandledError = wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
            error,
            view: view,
            closeAction: .dismiss,
            locale: selectedLocale,
            completionClosure: nil
        )

        if !isHandledError {
            logger?.error("Did receive error: \(error)")
        }
    }
}

extension TransferCrossChainConfirmPresenter: TransferConfirmPresenterProtocol {
    func setup() {
        provideAmountViewModel()
        provideOriginNetworkViewModel()
        provideDestinationNetworkViewModel()
        provideWalletViewModel()
        provideSenderViewModel()
        provideOriginFeeViewModel()
        provideCrossChainFeeViewModel()
        provideRecepientViewModel()

        interactor.setup()
    }

    func submit() {
        let assetPresicion = originChainAsset.assetDisplayInfo.assetPrecision
        guard
            let amountInPlank = amount.toSubstrateAmount(precision: assetPresicion),
            let utilityAsset = originChainAsset.chain.utilityAsset() else {
            return
        }

        let utilityAssetInfo = ChainAsset(chain: originChainAsset.chain, asset: utilityAsset).assetDisplayInfo

        let validators: [DataValidating] = baseValidators(
            for: getSendingAmount(),
            recepientAddress: recepientAccountAddress,
            utilityAssetInfo: utilityAssetInfo,
            selectedLocale: selectedLocale
        )

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            guard let strongSelf = self, let crossChainFee = self?.crossChainFee else {
                return
            }

            strongSelf.view?.didStartLoading()

            strongSelf.interactor.submit(
                amount: amountInPlank + crossChainFee.holdingPart,
                recepient: strongSelf.recepientAccountAddress,
                originFee: strongSelf.networkFee
            )
        }
    }

    func showSenderActions() {
        guard let senderAddress = wallet.fetch(for: originChainAsset.chain.accountRequest())?.toAddress() else {
            return
        }

        presentOptions(for: senderAddress, chain: originChainAsset.chain)
    }

    func showRecepientActions() {
        presentOptions(for: recepientAccountAddress, chain: destinationChainAsset.chain)
    }
}

extension TransferCrossChainConfirmPresenter: TransferConfirmCrossChainInteractorOutputProtocol {
    func didCompleteSubmition(by sender: ExtrinsicSenderResolution) {
        view?.didStopLoading()

        // Note: that transferCompletion is not called for delayed transfers
        wireframe.presentExtrinsicSubmission(
            from: view,
            sender: sender,
            completionAction: .dismissWithPostNavigation { [originChainAsset, transferCompletion] in
                transferCompletion?(originChainAsset)
            },
            locale: selectedLocale
        )
    }
}

extension TransferCrossChainConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideOriginFeeViewModel()
            provideCrossChainFeeViewModel()
        }
    }
}
