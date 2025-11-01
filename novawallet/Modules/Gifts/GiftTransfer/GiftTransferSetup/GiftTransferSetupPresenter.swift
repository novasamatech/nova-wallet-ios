import Foundation
import Foundation_iOS
import BigInt

final class GiftTransferSetupPresenter: GiftTransferPresenter, GiftTransferSetupInteractorOutputProtocol {
    weak var view: GiftTransferSetupViewProtocol?
    let wireframe: GiftTransferSetupWireframeProtocol
    let interactor: GiftTransferSetupInteractorInputProtocol

    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let issueViewModelFactory: GiftSetupIssueViewModelFactoryProtocol

    var inputResult: AmountInputResult?

    init(
        interactor: GiftTransferSetupInteractorInputProtocol,
        wireframe: GiftTransferSetupWireframeProtocol,
        chainAsset: ChainAsset,
        initialState: TransferSetupInputState,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        issueViewModelFactory: GiftSetupIssueViewModelFactoryProtocol,
        senderAccountAddress: AccountAddress,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.issueViewModelFactory = issueViewModelFactory
        inputResult = initialState.amount

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

    // MARK: Overrides

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

        interactor.estimateFee(for: amount)
    }

    override func askFeeRetry() {
        wireframe.presentFeeStatus(
            on: view,
            locale: selectedLocale
        ) { [weak self] in
            self?.refreshFee()
        }
    }

    override func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance) {
        super.didReceiveSendingAssetSenderBalance(balance)

        updateTransferableBalance()
    }

    override func didReceiveFee(result: Result<FeeOutputModel, Error>) {
        super.didReceiveFee(result: result)

        switch result {
        case .success:
            updateFeeView()
            updateAmountPriceView()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    override func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        super.didReceiveSendingAssetPrice(priceData)

        updateFeeView()
        updateAmountPriceView()
    }

    override func didReceiveError(_ error: Error) {
        super.didReceiveError(error)

        logger?.debug("Did receive error: \(error)")

        _ = wireframe.present(
            error: error,
            from: view,
            locale: selectedLocale
        )
    }
}

// MARK: - Private

private extension GiftTransferSetupPresenter {
    func updateChainAssetViewModel() {
        let viewModel = chainAssetViewModelFactory.createViewModel(from: chainAsset)
        view?.didReceiveInputChainAsset(viewModel: viewModel)
    }

    func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    func updateFeeView() {
        guard let fee else {
            view?.didReceiveFee(viewModel: .loading)
            return
        }

        let assetInfo = chainAsset.asset.displayInfo

        let feeDecimal = Decimal.fromSubstrateAmount(
            fee.value.amount,
            precision: assetInfo.assetPrecision
        ) ?? 0.0

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
            feeDecimal,
            priceData: assetPrice
        ).value(for: selectedLocale)

        let viewModel = NetworkFeeInfoViewModel(
            isEditable: false,
            balanceViewModel: balanceViewModel
        )

        let loadableViewModel = LoadableViewModelState<NetworkFeeInfoViewModel>.loaded(value: viewModel)

        view?.didReceiveFee(viewModel: loadableViewModel)
    }

    func updateTransferableBalance() {
        guard let assetBalance else { return }

        let precision = chainAsset.asset.displayInfo.assetPrecision
        let balanceDecimal = Decimal.fromSubstrateAmount(
            assetBalance.transferable,
            precision: precision
        ) ?? 0

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            balanceDecimal,
            priceData: nil
        ).value(for: selectedLocale).amount

        view?.didReceiveTransferableBalance(viewModel: viewModel)
    }

    func updateAmountPriceView() {
        guard chainAsset.asset.priceId != nil else {
            view?.didReceiveAmountInputPrice(viewModel: nil)
            return
        }

        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        let priceData = assetPrice ?? PriceData.zero()

        let price = balanceViewModelFactory.priceFromAmount(
            inputAmount,
            priceData: priceData
        ).value(for: selectedLocale)

        view?.didReceiveAmountInputPrice(viewModel: price)
    }

    func balanceMinusFee() -> Decimal {
        let balanceValue = assetBalance?.transferable ?? 0
        let feeValue = fee?.value.amountForCurrentAccount ?? 0

        let precision = chainAsset.assetDisplayInfo.assetPrecision

        guard
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let fee = Decimal.fromSubstrateAmount(feeValue, precision: precision)
        else { return 0 }

        return balance - fee
    }

    func updateTitle() {
        let strings = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable

        let titleText = strings.giftTransferSetupTokenTitle()
        let onText = strings.walletTransferOn()

        let viewModel = GiftSetupNetworkContainerViewModel(
            titleText: titleText,
            onText: onText,
            chainAssetModel: chainAssetViewModelFactory.createViewModel(from: chainAsset)
        )

        view?.didReceive(title: viewModel)
    }

    func getIssueParams() -> GiftSetupIssueCheckParams {
        .init(
            chainAsset: chainAsset,
            enteredAmount: inputResult?.absoluteValue(from: balanceMinusFee()),
            assetBalance: assetBalance,
            assetExistence: assetExistence,
            fee: fee?.value
        )
    }

    func provideIssues() {
        let issues = issueViewModelFactory.detectIssues(
            in: getIssueParams(),
            locale: selectedLocale
        )
        view?.didReceive(issues: issues)
    }
}

// MARK: - GiftTransferSetupPresenterProtocol

extension GiftTransferSetupPresenter: GiftTransferSetupPresenterProtocol {
    func setup() {
        updateChainAssetViewModel()
        updateFeeView()
        provideAmountInputViewModel()
        updateAmountPriceView()
        updateTitle()

        interactor.setup()
        refreshFee()
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { .absolute($0) }

        refreshFee()
        updateAmountPriceView()
        provideIssues()
    }

    func proceed() {
        let sendingAmount = inputResult?.absoluteValue(from: balanceMinusFee())
        var validators: [DataValidating] = baseValidators(
            for: sendingAmount,
            feeAssetInfo: chainAsset.assetDisplayInfo,
            view: view,
            selectedLocale: selectedLocale
        )

        validators.append(contentsOf: [
            dataValidatingFactory.willBeReaped(
                amount: sendingAmount,
                fee: fee?.value,
                totalAmount: assetBalance?.balanceCountingEd,
                minBalance: assetExistence?.minBalance,
                locale: selectedLocale
            )
        ])

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            guard
                let self,
                let sendingAmount
            else { return }

            logger?.debug("Did complete validation")

            let amount: OnChainTransferAmount<Decimal>

            if let inputResult = inputResult, inputResult.isMax {
                amount = .all(value: sendingAmount)
            } else {
                amount = .concrete(value: sendingAmount)
            }

            wireframe.showConfirmation(
                from: view,
                chainAsset: chainAsset,
                sendingAmount: amount
            )
        }
    }

    func getTokens() {
        wireframe.showGetTokenOptions(
            from: view,
            purchaseHadler: self,
            destinationChainAsset: chainAsset,
            locale: selectedLocale
        )
    }
}

// MARK: - RampFlowManaging, RampDelegate

extension GiftTransferSetupPresenter: RampFlowManaging, RampDelegate {
    func rampDidComplete(
        action: RampActionType,
        chainAsset _: ChainAsset
    ) {
        wireframe.popTopControllers(from: view) { [weak self] in
            guard let self else { return }

            wireframe.presentRampDidComplete(
                view: view,
                action: action,
                locale: selectedLocale
            )
        }
    }
}

// MARK: - Localizable

extension GiftTransferSetupPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }

        updateChainAssetViewModel()
        updateFeeView()
        updateTransferableBalance()
        provideAmountInputViewModel()
        updateAmountPriceView()
    }
}
