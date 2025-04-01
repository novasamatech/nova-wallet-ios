import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

final class CrossChainTransferSetupPresenter: CrossChainTransferPresenter,
    CrossChainTransferSetupInteractorOutputProtocol {
    weak var view: TransferSetupChildViewProtocol?
    let wireframe: CrossChainTransferSetupWireframeProtocol
    let interactor: CrossChainTransferSetupInteractorInputProtocol

    private(set) var partialRecepientAddress: AccountAddress?

    let wallet: MetaAccountModel
    let phishingValidatingFactory: PhishingAddressValidatorFactoryProtocol
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol

    var inputResult: AmountInputResult?

    init(
        wallet: MetaAccountModel,
        interactor: CrossChainTransferSetupInteractorInputProtocol,
        wireframe: CrossChainTransferSetupWireframeProtocol,
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        initialState: TransferSetupInputState,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        phishingValidatingFactory: PhishingAddressValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.wallet = wallet
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        partialRecepientAddress = initialState.recepient
        inputResult = initialState.amount
        self.phishingValidatingFactory = phishingValidatingFactory

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
        try? partialRecepientAddress?.toAccountId(using: destinationChainAsset.chain.chainFormat)
    }

    private func updateChainAssetViewModel() {
        let viewModel = chainAssetViewModelFactory.createViewModel(from: originChainAsset)
        view?.didReceiveInputChainAsset(viewModel: viewModel)
    }

    private func provideRecepientStateViewModel() {
        if
            let accountId = getRecepientAccountId(),
            let icon = try? iconGenerator.generateFromAccountId(accountId) {
            let iconViewModel = DrawableIconViewModel(icon: icon)
            let viewModel = AccountFieldStateViewModel(icon: iconViewModel)
            view?.didReceiveAccountState(viewModel: viewModel)
        } else {
            let viewModel = AccountFieldStateViewModel(icon: nil)
            view?.didReceiveAccountState(viewModel: viewModel)
        }
    }

    private func provideRecepientInputViewModel() {
        let value = partialRecepientAddress ?? ""

        let inputViewModel = InputViewModel.createAccountInputViewModel(for: value)

        view?.didReceiveAccountInput(viewModel: inputViewModel)
    }

    private func provideAmountInputViewModelIfRate() {
        guard case .rate = inputResult else {
            return
        }

        provideAmountInputViewModel()
    }

    private func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: maxTransferrable())

        let viewModel = sendingBalanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func updateOriginFeeView() {
        let optAssetInfo = originChainAsset.chain.utilityAssets().first?.displayInfo
        if let fee = displayOriginFee, let assetInfo = optAssetInfo {
            let feeDecimal = Decimal.fromSubstrateAmount(
                fee,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let viewModelFactory = utilityBalanceViewModelFactory ?? sendingBalanceViewModelFactory
            let priceData = isOriginUtilityTransfer ? sendingAssetPrice : utilityAssetPrice

            let balanceViewModel = viewModelFactory.balanceFromPrice(
                feeDecimal,
                priceData: priceData
            ).value(for: selectedLocale)

            let viewModel = NetworkFeeInfoViewModel(
                isEditable: false,
                balanceViewModel: balanceViewModel
            )

            let loadableViewModel = LoadableViewModelState<NetworkFeeInfoViewModel>.loaded(value: viewModel)

            view?.didReceiveOriginFee(viewModel: loadableViewModel)
        } else {
            view?.didReceiveOriginFee(viewModel: .loading)
        }
    }

    private func updateCrossChainFeeView() {
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

    private func updateTransferableBalance() {
        if let senderSendingAssetBalance = senderSendingAssetBalance {
            let precision = originChainAsset.asset.displayInfo.assetPrecision
            let balanceDecimal = Decimal.fromSubstrateAmount(
                senderSendingAssetBalance.transferable,
                precision: precision
            ) ?? 0

            let viewModel = sendingBalanceViewModelFactory.balanceFromPrice(
                balanceDecimal,
                priceData: nil
            ).value(for: selectedLocale).amount

            view?.didReceiveTransferableBalance(viewModel: viewModel)
        }
    }

    private func updateAmountPriceView() {
        if originChainAsset.asset.priceId != nil {
            let inputAmount = inputResult?.absoluteValue(from: maxTransferrable()) ?? 0

            let priceData = sendingAssetPrice ?? PriceData.zero()

            let price = sendingBalanceViewModelFactory.priceFromAmount(
                inputAmount,
                priceData: priceData
            ).value(for: selectedLocale)

            view?.didReceiveAmountInputPrice(viewModel: price)
        } else {
            view?.didReceiveAmountInputPrice(viewModel: nil)
        }
    }

    private func provideCanSendMySelf() {
        let destinationAccountExists = wallet.fetch(for: destinationChainAsset.chain.accountRequest()) != nil
        view?.didReceiveCanSendMySelf(destinationAccountExists)
    }

    private func maxTransferrable() -> Decimal {
        let balanceValue = senderSendingAssetBalance?.transferable ?? 0
        let balanceCountingEdValue = senderSendingAssetBalance?.balanceCountingEd ?? 0
        let originFeeValue = isOriginUtilityTransfer ? displayOriginFee ?? 0 : 0
        let crossChainFeeValue = displayCrosschainFee ?? 0

        /**
         *  Currently relaychains has an issue that leads to xcm fail if account's balance goes bellow ed
         *  before paying delivery fee. So make sure we will have at least ed and don't burn any tokens on account kill
         */
        let hasOriginDeliveryFee = (crossChainFee?.senderPart ?? 0) > 0
        let keepAlive = (hasOriginDeliveryFee && isOriginUtilityTransfer) || (requiresOriginKeepAlive ?? false)
        let minimumBalanceValue = keepAlive ? originSendingMinBalance ?? 0 : 0

        let precision = originChainAsset.assetDisplayInfo.assetPrecision

        guard
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let balanceCountingEd = Decimal.fromSubstrateAmount(balanceCountingEdValue, precision: precision),
            let originFee = Decimal.fromSubstrateAmount(originFeeValue, precision: precision),
            let crossChainFee = Decimal.fromSubstrateAmount(crossChainFeeValue, precision: precision),
            let minimumBalance = Decimal.fromSubstrateAmount(minimumBalanceValue, precision: precision) else {
            return 0
        }

        let balanceWithoutFee = balance - originFee - crossChainFee
        let balanceCountingEdWithoutFee = balanceCountingEd - originFee - crossChainFee - minimumBalance

        return min(balanceWithoutFee, balanceCountingEdWithoutFee)
    }

    private func updateRecepientAddress(_ newAddress: String) {
        guard partialRecepientAddress != newAddress else {
            return
        }

        partialRecepientAddress = newAddress

        let optAccountId = getRecepientAccountId()

        interactor.change(recepient: optAccountId)

        if optAccountId == nil {
            resetRecepientBalance()
        }

        provideRecepientStateViewModel()

        refreshCrossChainFee()
    }

    // MARK: Subsclass

    override func refreshOriginFee() {
        let inputAmount = inputResult?.absoluteValue(from: maxTransferrable()) ?? 0
        let assetInfo = originChainAsset.assetDisplayInfo

        guard let amount = inputAmount.toSubstrateAmount(
            precision: assetInfo.assetPrecision
        ) else {
            return
        }

        updateOriginFee(nil)
        updateOriginFeeView()

        interactor.estimateOriginFee(
            for: amount,
            recepient: getRecepientAccountId()
        )
    }

    override func refreshCrossChainFee() {
        let inputAmount = inputResult?.absoluteValue(from: maxTransferrable()) ?? 0
        let assetInfo = originChainAsset.assetDisplayInfo

        guard let amount = inputAmount.toSubstrateAmount(
            precision: assetInfo.assetPrecision
        ) else {
            return
        }

        updateCrossChainFee(nil)
        updateCrossChainFeeView()

        interactor.estimateCrossChainFee(for: amount, recepient: getRecepientAccountId())
    }

    override func askCrossChainFeeRetry() {
        wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.refreshCrossChainFee()
        }
    }

    override func askOriginFeeRetry() {
        wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.refreshOriginFee()
        }
    }

    override func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance) {
        super.didReceiveSendingAssetSenderBalance(balance)

        updateTransferableBalance()
    }

    override func didReceiveOriginFee(result: Result<ExtrinsicFeeProtocol, Error>) {
        super.didReceiveOriginFee(result: result)

        if case .success = result {
            updateOriginFeeView()
            provideAmountInputViewModelIfRate()
            updateAmountPriceView()
        }
    }

    override func didReceiveCrossChainFee(result: Result<XcmFeeModelProtocol, Error>) {
        super.didReceiveCrossChainFee(result: result)

        logger?.debug("Did receive result: \(result)")

        if case .success = result {
            updateOriginFeeView()
            updateCrossChainFeeView()
            provideAmountInputViewModelIfRate()
            updateAmountPriceView()
            refreshOriginFee()
        }
    }

    override func didReceiveOriginSendingMinBalance(_ value: BigUInt) {
        super.didReceiveOriginSendingMinBalance(value)

        provideAmountInputViewModelIfRate()
    }

    override func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        super.didReceiveSendingAssetPrice(priceData)

        if isOriginUtilityTransfer {
            updateOriginFeeView()
        }

        updateCrossChainFeeView()
        updateAmountPriceView()
    }

    override func didReceiveUtilityAssetPrice(_ priceData: PriceData?) {
        super.didReceiveUtilityAssetPrice(priceData)

        updateOriginFeeView()
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

        _ = wireframe.present(error: error, from: view, locale: selectedLocale)
    }

    override func getSendingAmount() -> Decimal? {
        inputResult?.absoluteValue(from: maxTransferrable())
    }
}

extension CrossChainTransferSetupPresenter: TransferSetupChildPresenterProtocol {
    var inputState: TransferSetupInputState {
        TransferSetupInputState(recepient: partialRecepientAddress, amount: inputResult)
    }

    func setup() {
        updateChainAssetViewModel()
        updateOriginFeeView()
        updateCrossChainFeeView()
        provideRecepientStateViewModel()
        provideRecepientInputViewModel()
        provideCanSendMySelf()
        provideAmountInputViewModel()
        updateAmountPriceView()

        interactor.setup()
    }

    func updateRecepient(partialAddress: String) {
        updateRecepientAddress(partialAddress)
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }

        refreshOriginFee()
        refreshCrossChainFee()
        updateAmountPriceView()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()

        refreshOriginFee()
        refreshCrossChainFee()
        updateAmountPriceView()
    }

    func changeRecepient(address: String) {
        updateRecepientAddress(address)
        provideRecepientInputViewModel()
    }

    func proceed() {
        guard let utilityAsset = originChainAsset.chain.utilityAsset() else {
            return
        }

        let utilityAssetInfo = ChainAsset(chain: originChainAsset.chain, asset: utilityAsset).assetDisplayInfo

        let sendingAmount = getSendingAmount()

        var validators: [DataValidating] = baseValidators(
            for: sendingAmount,
            recepientAddress: partialRecepientAddress,
            utilityAssetInfo: utilityAssetInfo,
            selectedLocale: selectedLocale
        )

        validators.append(contentsOf: [
            dataValidatingFactory.accountIsNotSystem(
                for: getRecepientAccountId(),
                locale: selectedLocale
            ),

            dataValidatingFactory.willBeReaped(
                amount: getTotalSpendingWithoutNetworkFee(),
                fee: isOriginUtilityTransfer ? networkFee : nil,
                totalAmount: senderSendingAssetBalance?.balanceCountingEd,
                minBalance: originSendingMinBalance,
                locale: selectedLocale
            )
        ])

        validators.append(
            phishingValidatingFactory.notPhishing(
                address: partialRecepientAddress,
                locale: selectedLocale
            )
        )

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            guard
                let amount = sendingAmount,
                let recepient = self?.partialRecepientAddress,
                let originChainAsset = self?.originChainAsset,
                let destinationChainAsset = self?.destinationChainAsset else {
                return
            }

            self?.logger?.debug("Did complete validation")

            self?.wireframe.showConfirmation(
                from: self?.view,
                originChainAsset: originChainAsset,
                destinationChainAsset: destinationChainAsset,
                sendingAmount: amount,
                recepient: recepient
            )
        }
    }
}

extension CrossChainTransferSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateChainAssetViewModel()
            updateOriginFeeView()
            updateTransferableBalance()
            provideRecepientStateViewModel()
            provideRecepientInputViewModel()
            provideAmountInputViewModel()
            updateAmountPriceView()
        }
    }
}
