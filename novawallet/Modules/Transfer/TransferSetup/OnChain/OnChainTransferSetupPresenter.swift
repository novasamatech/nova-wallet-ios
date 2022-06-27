import Foundation
import BigInt
import SoraFoundation
import SubstrateSdk

final class OnChainTransferSetupPresenter: OnChainTransferPresenter, OnChainTransferSetupInteractorOutputProtocol {
    weak var view: TransferSetupChildViewProtocol?
    let wireframe: OnChainTransferSetupWireframeProtocol
    let interactor: OnChainTransferSetupInteractorInputProtocol

    private(set) var recepientAddress: AccountAddress?

    let phishingValidatingFactory: PhishingAddressValidatorFactoryProtocol
    let initialState: TransferSetupInputState?

    var inputResult: AmountInputResult?

    init(
        interactor: OnChainTransferSetupInteractorInputProtocol,
        wireframe: OnChainTransferSetupWireframeProtocol,
        chainAsset: ChainAsset,
        initialState: TransferSetupInputState,
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
        self.initialState = initialState
        self.phishingValidatingFactory = phishingValidatingFactory

        super.init(
            chainAsset: chainAsset,
            networkViewModelFactory: networkViewModelFactory,
            sendingBalanceViewModelFactory: sendingBalanceViewModelFactory,
            utilityBalanceViewModelFactory: utilityBalanceViewModelFactory,
            senderAccountAddress: senderAccountAddress,
            dataValidatingFactory: dataValidatingFactory,
            logger: logger
        )

        self.localizationManager = localizationManager
    }

    private func updateChainAssetViewModel() {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)

        let assetIconUrl = chainAsset.asset.icon ?? chainAsset.chain.icon
        let assetIconViewModel = RemoteImageViewModel(url: assetIconUrl)

        let assetViewModel = AssetViewModel(
            symbol: chainAsset.asset.symbol,
            imageViewModel: assetIconViewModel
        )

        let viewModel = ChainAssetViewModel(
            networkViewModel: networkViewModel,
            assetViewModel: assetViewModel
        )

        view?.didReceiveInputChainAsset(viewModel: viewModel)
    }

    private func provideRecepientStateViewModel() {
        if
            let recepientAddress = recepientAddress,
            let accountId = try? recepientAddress.toAccountId(),
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
        let value = recepientAddress ?? ""

        provideRecepientInputViewModel(for: value)
    }

    private func provideRecepientInputViewModel(for address: AccountAddress) {
        let inputViewModel = InputViewModel.createAccountInputViewModel(for: address)

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

    private func updateFeeView() {
        let optAssetInfo = chainAsset.chain.utilityAssets().first?.displayInfo
        if let fee = fee, let assetInfo = optAssetInfo {
            let feeDecimal = Decimal.fromSubstrateAmount(
                fee,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let viewModelFactory = utilityBalanceViewModelFactory ?? sendingBalanceViewModelFactory
            let priceData = isUtilityTransfer ? sendingAssetPrice : utilityAssetPrice

            let viewModel = viewModelFactory.balanceFromPrice(
                feeDecimal,
                priceData: priceData
            ).value(for: selectedLocale)

            view?.didReceiveOriginFee(viewModel: viewModel)
        } else {
            view?.didReceiveOriginFee(viewModel: nil)
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

            let priceData = sendingAssetPrice ?? PriceData(price: "0", usdDayChange: nil)

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
        let feeValue = isUtilityTransfer ? (fee ?? 0) : 0

        let precision = chainAsset.assetDisplayInfo.assetPrecision

        guard
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let fee = Decimal.fromSubstrateAmount(feeValue, precision: precision) else {
            return 0
        }

        return balance - fee
    }

    private func updateRecepientFieldIfValue(_ newAddress: String) {
        let accountId = try? newAddress.toAccountId(using: chainAsset.chain.chainFormat)
        if accountId != nil {
            recepientAddress = newAddress
        } else {
            recepientAddress = nil
        }
    }

    private func updateRecepientAddress(_ newAddress: String) {
        updateRecepientFieldIfValue(newAddress)

        interactor.change(recepient: recepientAddress)

        provideRecepientStateViewModel()

        refreshFee()
    }

    // MARK: Subsclass

    override func refreshFee() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
        let assetInfo = chainAsset.assetDisplayInfo

        guard let amount = inputAmount.toSubstrateAmount(
            precision: assetInfo.assetPrecision
        ) else {
            return
        }

        updateFee(nil)
        updateFeeView()

        interactor.estimateFee(for: amount, recepient: recepientAddress)
    }

    override func askFeeRetry() {
        wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.refreshFee()
        }
    }

    override func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance) {
        super.didReceiveSendingAssetSenderBalance(balance)

        updateTransferableBalance()
    }

    override func didReceiveFee(result: Result<BigUInt, Error>) {
        super.didReceiveFee(result: result)

        if case .success = result {
            updateFeeView()
            provideAmountInputViewModelIfRate()
            updateAmountPriceView()
        }
    }

    override func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        super.didReceiveSendingAssetPrice(priceData)

        if isUtilityTransfer {
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

        refreshFee()

        interactor.change(recepient: recepientAddress)
    }

    override func didReceiveError(_ error: Error) {
        super.didReceiveError(error)

        _ = wireframe.present(error: error, from: view, locale: selectedLocale)
    }
}

extension OnChainTransferSetupPresenter: TransferSetupChildPresenterProtocol {
    var inputState: TransferSetupInputState {
        TransferSetupInputState(recepient: recepientAddress, amount: inputResult)
    }

    func setup() {
        updateChainAssetViewModel()
        updateFeeView()

        if let receiverAddress = initialState?.recepient {
            updateRecepientFieldIfValue(receiverAddress)
            provideRecepientStateViewModel()
            provideRecepientInputViewModel(for: receiverAddress)
        } else {
            provideRecepientStateViewModel()
            provideRecepientInputViewModel()
        }

        inputResult = initialState?.amount
        provideAmountInputViewModel()
        updateAmountPriceView()

        interactor.setup()
    }

    func updateRecepient(partialAddress: String) {
        updateRecepientAddress(partialAddress)
    }

    func changeRecepient(address: String) {
        guard address != recepientAddress else {
            return
        }

        recepientAddress = address
        provideRecepientInputViewModel()
        updateRecepientAddress(address)
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
        let sendingAmount = inputResult?.absoluteValue(from: balanceMinusFee())
        var validators: [DataValidating] = baseValidators(
            for: sendingAmount,
            recepientAddress: recepientAddress,
            selectedLocale: selectedLocale
        )

        validators.append(
            dataValidatingFactory.willBeReaped(
                amount: sendingAmount,
                fee: isUtilityTransfer ? fee : 0,
                totalAmount: senderSendingAssetBalance?.totalInPlank,
                minBalance: sendingAssetExistence?.minBalance,
                locale: selectedLocale
            )
        )

        validators.append(
            phishingValidatingFactory.notPhishing(
                address: recepientAddress,
                locale: selectedLocale
            )
        )

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            guard
                let amount = sendingAmount,
                let recepient = self?.recepientAddress,
                let chainAsset = self?.chainAsset else {
                return
            }

            self?.logger?.debug("Did complete validation")

            self?.wireframe.showConfirmation(
                from: self?.view,
                chainAsset: chainAsset,
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
