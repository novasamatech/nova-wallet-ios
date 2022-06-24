import Foundation
import BigInt
import SoraFoundation
import SubstrateSdk

final class CrossChainTransferSetupPresenter: CrossChainTransferPresenter,
                                            CrossChainTransferSetupInteractorOutputProtocol {
    weak var view: TransferSetupChildViewProtocol?
    let wireframe: CrossChainTransferSetupWireframeProtocol
    let interactor: CrossChainTransferSetupInteractorInputProtocol

    private(set) var recepientAddress: AccountAddress?

    let phishingValidatingFactory: PhishingAddressValidatorFactoryProtocol

    var inputResult: AmountInputResult?

    init(
        interactor: CrossChainTransferSetupInteractorInputProtocol,
        wireframe: CrossChainTransferSetupWireframeProtocol,
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
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
        recepientAddress = initialState.recepient
        inputResult = initialState.amount
        self.phishingValidatingFactory = phishingValidatingFactory

        super.init(
            originChainAsset: originChainAsset,
            destinationChainAsset: destinationChainAsset,
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
        let networkViewModel = networkViewModelFactory.createViewModel(from: originChainAsset.chain)

        let assetIconUrl = originChainAsset.asset.icon ?? originChainAsset.chain.icon
        let assetIconViewModel = RemoteImageViewModel(url: assetIconUrl)

        let assetViewModel = AssetViewModel(
            symbol: originChainAsset.asset.symbol,
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

    private func updateFeeView() {
        let optAssetInfo = originChainAsset.chain.utilityAssets().first?.displayInfo
        if let fee = originFee, let assetInfo = optAssetInfo {
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

            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
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
        let feeValue = isUtilityTransfer ? (originFee ?? 0) : 0

        let precision = originChainAsset.assetDisplayInfo.assetPrecision

        guard
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let fee = Decimal.fromSubstrateAmount(feeValue, precision: precision) else {
            return 0
        }

        return balance - fee
    }

    private func updateRecepientAddress(_ newAddress: String) {
        let accountId = try? newAddress.toAccountId(using: destinationChainAsset.chain.chainFormat)
        if accountId != nil {
            recepientAddress = newAddress
        } else {
            recepientAddress = nil
        }

        interactor.change(recepient: recepientAddress)

        provideRecepientStateViewModel()

        refreshOriginFee()
    }

    // MARK: Subsclass

    override func refreshOriginFee() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
        let assetInfo = originChainAsset.assetDisplayInfo

        guard let amount = inputAmount.toSubstrateAmount(
            precision: assetInfo.assetPrecision
        ) else {
            return
        }

        updateOriginFee(nil)
        updateFeeView()

        let weightLimit = crossChainFee?.weight ?? 0

        interactor.estimateOriginFee(for: amount, recepient: recepientAddress, weightLimit: weightLimit)
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

    override func didReceiveOriginFee(result: Result<BigUInt, Error>) {
        super.didReceiveOriginFee(result: result)

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

        refreshOriginFee()
        refreshCrossChainFee()

        interactor.change(recepient: recepientAddress)
    }

    override func didReceiveError(_ error: Error) {
        super.didReceiveError(error)

        _ = wireframe.present(error: error, from: view, locale: selectedLocale)
    }
}

extension CrossChainTransferSetupPresenter: TransferSetupChildPresenterProtocol {
    var inputState: TransferSetupInputState {
        TransferSetupInputState(recepient: recepientAddress, amount: inputResult)
    }

    func setup() {
        updateChainAssetViewModel()
        updateFeeView()
        provideRecepientStateViewModel()
        provideRecepientInputViewModel()
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

    func scanRecepientCode() {
        wireframe.showRecepientScan(from: view, delegate: self)
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
                fee: isUtilityTransfer ? originFee : 0,
                totalAmount: senderSendingAssetBalance?.totalInPlank,
                minBalance: sendingAssetMinBalance,
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
            updateFeeView()
            updateTransferableBalance()
            provideRecepientStateViewModel()
            provideRecepientInputViewModel()
            provideAmountInputViewModel()
            updateAmountPriceView()
        }
    }
}

extension CrossChainTransferSetupPresenter: TransferScanDelegate {
    func transferScanDidReceiveRecepient(address: AccountAddress) {
        wireframe.hideRecepientScan(from: view)

        guard recepientAddress != address else {
            return
        }

        recepientAddress = address

        provideRecepientInputViewModel()

        updateRecepientAddress(address)
    }
}
