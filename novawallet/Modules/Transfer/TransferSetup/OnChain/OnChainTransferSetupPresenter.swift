import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

final class OnChainTransferSetupPresenter: OnChainTransferPresenter, OnChainTransferSetupInteractorOutputProtocol {
    weak var view: TransferSetupChildViewProtocol?
    let wireframe: OnChainTransferSetupWireframeProtocol
    let interactor: OnChainTransferSetupInteractorInputProtocol

    private(set) var partialRecepientAddress: AccountAddress?
    private var isManualFeeSet: Bool = false

    let phishingValidatingFactory: PhishingAddressValidatorFactoryProtocol
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol

    var inputResult: AmountInputResult?

    init(
        interactor: OnChainTransferSetupInteractorInputProtocol,
        wireframe: OnChainTransferSetupWireframeProtocol,
        chainAsset: ChainAsset,
        feeAsset: ChainAsset,
        initialState: TransferSetupInputState,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        senderAccountAddress: AccountAddress,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        phishingValidatingFactory: PhishingAddressValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        partialRecepientAddress = initialState.recepient
        inputResult = initialState.amount
        self.phishingValidatingFactory = phishingValidatingFactory

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
        try? partialRecepientAddress?.toAccountId(using: chainAsset.chain.chainFormat)
    }

    private func updateChainAssetViewModel() {
        let viewModel = chainAssetViewModelFactory.createViewModel(from: chainAsset)
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
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let viewModel = sendingBalanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    private func provideCanSendMySelf() {
        view?.didReceiveCanSendMySelf(false)
    }

    private func switchFeeChainAssetIfNecessary() {
        guard
            let fee,
            feeAssetChangeAvailable,
            !isManualFeeSet,
            !chainAsset.isUtilityAsset,
            feeAsset.isUtilityAsset,
            let utilityAssetMinBalance,
            let senderUtilityAssetBalance,
            let senderSendingAssetBalance,
            senderSendingAssetBalance.transferable > 0
        else {
            return
        }

        if senderUtilityAssetBalance.transferable.subtractOrZero(fee.value.amount) < utilityAssetMinBalance {
            changeFeeAsset(to: chainAsset)
        }
    }

    func changeFeeAsset(to chainAsset: ChainAsset) {
        feeAsset = chainAsset

        interactor.change(feeAsset: chainAsset)
        refreshFee()
    }

    private func updateFeeView() {
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

            let viewModel = NetworkFeeInfoViewModel(
                isEditable: feeAssetChangeAvailable,
                balanceViewModel: balanceViewModel
            )

            let loadableViewModel = LoadableViewModelState<NetworkFeeInfoViewModel>.loaded(value: viewModel)

            view?.didReceiveOriginFee(viewModel: loadableViewModel)
        } else {
            view?.didReceiveOriginFee(viewModel: .loading)
        }
    }

    private func updateTransferableBalance() {
        if let senderSendingAssetBalance = senderSendingAssetBalance {
            let precision = chainAsset.asset.displayInfo.assetPrecision
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
        if chainAsset.asset.priceId != nil {
            let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

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

    private func balanceMinusFee() -> Decimal {
        let balanceValue = senderSendingAssetBalance?.transferable ?? 0
        let feeValue = sendingAssetFeeSelected
            ? (fee?.value.amountForCurrentAccount ?? 0)
            : 0

        let precision = chainAsset.assetDisplayInfo.assetPrecision

        guard
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let fee = Decimal.fromSubstrateAmount(feeValue, precision: precision) else {
            return 0
        }

        return balance - fee
    }

    private func updateRecepientAddress(_ newAddress: String) {
        guard partialRecepientAddress != newAddress else {
            return
        }

        partialRecepientAddress = newAddress

        let optAccountId = getRecepientAccountId()

        if optAccountId != nil {
            resetRecepientBalance()
        }

        interactor.change(recepient: optAccountId)

        provideRecepientStateViewModel()

        refreshFee()
    }

    // MARK: Subsclass

    override func refreshFee() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
        let assetInfo = chainAsset.assetDisplayInfo

        guard let amountValue = inputAmount.toSubstrateAmount(
            precision: assetInfo.assetPrecision
        ) else {
            return
        }

        let amount: OnChainTransferAmount<BigUInt>

        if let inputResult = inputResult, inputResult.isMax {
            amount = .all(value: amountValue)
        } else {
            amount = .concrete(value: amountValue)
        }

        updateFee(nil)
        updateFeeView()

        interactor.estimateFee(for: amount, recepient: getRecepientAccountId())
    }

    override func askFeeRetry() {
        wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.refreshFee()
        }
    }

    override func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance) {
        super.didReceiveSendingAssetSenderBalance(balance)

        updateTransferableBalance()
        switchFeeChainAssetIfNecessary()
    }

    override func didReceiveUtilityAssetSenderBalance(_ balance: AssetBalance) {
        super.didReceiveUtilityAssetSenderBalance(balance)

        switchFeeChainAssetIfNecessary()
    }

    override func didReceiveFee(result: Result<FeeOutputModel, Error>) {
        super.didReceiveFee(result: result)

        if case .success = result {
            switchFeeChainAssetIfNecessary()
            updateFeeView()
            provideAmountInputViewModelIfRate()
            updateAmountPriceView()
        } else {
            logger?.error("Did receive fee error: \(result)")
        }
    }

    override func didReceiveCustomAssetFeeAvailable(_ available: Bool) {
        super.didReceiveCustomAssetFeeAvailable(available)

        refreshFee()
    }

    override func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        super.didReceiveSendingAssetPrice(priceData)

        if sendingAssetFeeSelected {
            updateFeeView()
        }

        updateAmountPriceView()
    }

    override func didReceiveUtilityAssetPrice(_ priceData: PriceData?) {
        super.didReceiveUtilityAssetPrice(priceData)

        updateFeeView()
    }

    override func didCompleteSetup() {
        super.didCompleteSetup()

        interactor.change(recepient: getRecepientAccountId())
        interactor.requestFeePaymentAvailability(for: chainAsset)
    }

    override func didReceiveError(_ error: Error) {
        super.didReceiveError(error)

        logger?.debug("Did receive error: \(error)")

        _ = wireframe.present(error: error, from: view, locale: selectedLocale)
    }
}

extension OnChainTransferSetupPresenter: TransferSetupChildPresenterProtocol {
    func getFeeAsset() -> ChainAsset? {
        feeAsset
    }

    func changeFeeAsset(to chainAsset: ChainAsset?) {
        guard let chainAsset else { return }

        isManualFeeSet = true

        changeFeeAsset(to: chainAsset)
    }

    var inputState: TransferSetupInputState {
        TransferSetupInputState(recepient: partialRecepientAddress, amount: inputResult)
    }

    func setup() {
        updateChainAssetViewModel()
        updateFeeView()
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

    func changeRecepient(address: String) {
        updateRecepientAddress(address)
        provideRecepientInputViewModel()
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }

        refreshFee()
        updateAmountPriceView()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()

        refreshFee()
        updateAmountPriceView()
    }

    func proceed() {
        guard let utilityAsset = chainAsset.chain.utilityAsset() else {
            return
        }

        let sendingAmount = inputResult?.absoluteValue(from: balanceMinusFee())
        var validators: [DataValidating] = baseValidators(
            for: sendingAmount,
            recepientAddress: partialRecepientAddress,
            feeAssetInfo: feeAsset.assetDisplayInfo,
            view: view,
            selectedLocale: selectedLocale
        )

        validators.append(contentsOf: [
            dataValidatingFactory.accountIsNotSystem(
                for: getRecepientAccountId(),
                locale: selectedLocale
            ),

            dataValidatingFactory.willBeReaped(
                amount: sendingAmount,
                fee: sendingAssetFeeSelected ? fee?.value : nil,
                totalAmount: senderSendingAssetBalance?.balanceCountingEd,
                minBalance: sendingAssetExistence?.minBalance,
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
                let self,
                let amountValue = sendingAmount,
                let recepient = partialRecepientAddress
            else {
                return
            }

            logger?.debug("Did complete validation")

            let amount: OnChainTransferAmount<Decimal>

            if let inputResult = inputResult, inputResult.isMax {
                amount = .all(value: amountValue)
            } else {
                amount = .concrete(value: amountValue)
            }

            wireframe.showConfirmation(
                from: view,
                chainAsset: chainAsset,
                feeAsset: feeAsset,
                sendingAmount: amount,
                recepient: recepient
            )
        }
    }
}

extension OnChainTransferSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateChainAssetViewModel()
            updateFeeView()
            updateTransferableBalance()
            provideRecepientStateViewModel()
            provideRecepientInputViewModel()
            provideAmountInputViewModel()
            updateAmountPriceView()
        }
    }
}
