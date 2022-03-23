import Foundation
import BigInt
import SoraFoundation
import SubstrateSdk

final class TransferSetupPresenter: TransferPresenter, TransferSetupInteractorOutputProtocol {
    weak var view: TransferSetupViewProtocol?
    let wireframe: TransferSetupWireframeProtocol
    let interactor: TransferSetupInteractorInputProtocol

    private(set) var recepientAddress: AccountAddress?

    var inputResult: AmountInputResult?

    init(
        interactor: TransferSetupInteractorInputProtocol,
        wireframe: TransferSetupWireframeProtocol,
        chainAsset: ChainAsset,
        recepientAddress: AccountAddress?,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        senderAccountAddress: AccountAddress,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.recepientAddress = recepientAddress

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

        view?.didReceiveChainAsset(viewModel: viewModel)
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

            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
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

    private func refreshFee() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0
        let assetInfo = chainAsset.assetDisplayInfo

        guard let amount = inputAmount.toSubstrateAmount(
            precision: assetInfo.assetPrecision
        ) else {
            return
        }

        interactor.estimateFee(for: amount, recepient: recepientAddress)
    }

    // MARK: Protocol

    override func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance) {
        super.didReceiveSendingAssetSenderBalance(balance)

        updateTransferableBalance()
    }

    override func didReceiveFee(_ fee: BigUInt) {
        super.didReceiveFee(fee)

        updateFeeView()
        provideAmountInputViewModelIfRate()
        updateAmountPriceView()
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

    override func didReceiveSetup(error: Error) {
        super.didReceiveSetup(error: error)
    }
}

extension TransferSetupPresenter: TransferSetupPresenterProtocol {
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
        let accountId = try? partialAddress.toAccountId(using: chainAsset.chain.chainFormat)
        if accountId != nil {
            recepientAddress = partialAddress
        } else {
            recepientAddress = nil
        }

        interactor.change(recepient: recepientAddress)

        provideRecepientStateViewModel()
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

    func scanRecepientCode() {
        wireframe.showRecepientScan(from: view)
    }

    func proceed() {
        let sendingAmount = inputResult?.absoluteValue(from: balanceMinusFee())
        var validators: [DataValidating] = [
            dataValidatingFactory.receiverMatchesChain(
                recepient: recepientAddress,
                chainFormat: chainAsset.chain.chainFormat,
                chainName: chainAsset.chain.name,
                locale: selectedLocale
            ),

            dataValidatingFactory.receiverDiffers(
                recepient: recepientAddress,
                sender: senderAccountAddress,
                locale: selectedLocale
            ),

            dataValidatingFactory.has(fee: fee, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
                return
            },

            dataValidatingFactory.canSend(
                amount: sendingAmount,
                fee: isUtilityTransfer ? fee : 0,
                transferable: senderSendingAssetBalance?.transferable,
                locale: selectedLocale
            ),

            dataValidatingFactory.canPay(
                fee: fee,
                total: senderUtilityAssetTotal,
                minBalance: isUtilityTransfer ? sendingAssetMinBalance : utilityAssetMinBalance,
                locale: selectedLocale
            ),

            dataValidatingFactory.receiverWillHaveAssetAccount(
                sendingAmount: sendingAmount,
                totalAmount: recepientSendingAssetBalance?.totalInPlank,
                minBalance: sendingAssetMinBalance,
                locale: selectedLocale
            )
        ]

        if !isUtilityTransfer {
            validators.append(
                dataValidatingFactory.receiverHasUtilityAccount(
                    totalAmount: recepientUtilityAssetBalance?.totalInPlank,
                    minBalance: utilityAssetMinBalance,
                    locale: selectedLocale
                )
            )
        }

        validators.append(
            dataValidatingFactory.willBeReaped(
                amount: sendingAmount,
                fee: isUtilityTransfer ? fee : 0,
                totalAmount: senderSendingAssetBalance?.totalInPlank,
                minBalance: sendingAssetMinBalance,
                locale: selectedLocale
            )
        )

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            guard let amount = sendingAmount, let recepient = self?.recepientAddress else {
                return
            }

            self?.logger?.debug("Did complete validation")

            self?.wireframe.showConfirmation(
                from: self?.view,
                sendingAmount: amount,
                recepient: recepient
            )
        }
    }
}

extension TransferSetupPresenter: Localizable {
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
