import BigInt
import SoraFoundation

final class NominationPoolBondMorePresenter: NominationPoolBondMoreBasePresenter {
    var wireframe: NominationPoolBondMoreWireframeProtocol? {
        baseWireframe as? NominationPoolBondMoreWireframeProtocol
    }

    var interactor: NominationPoolBondMoreInteractorInputProtocol? {
        baseInteractor as? NominationPoolBondMoreInteractorInputProtocol
    }

    private var inputResult: AmountInputResult?

    init(
        interactor: NominationPoolBondMoreInteractorInputProtocol,
        wireframe: NominationPoolBondMoreWireframeProtocol,
        chainAsset: ChainAsset,
        hintsViewModelFactory: NominationPoolsBondMoreHintsFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol

    ) {
        super.init(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            hintsViewModelFactory: hintsViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatorFactory: dataValidatorFactory,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    func provideTransferrableBalance() {
        guard let balance = assetBalance?.transferable.decimal(precision: chainAsset.asset.precision) else {
            view?.didReceiveTransferable(viewModel: nil)
            return
        }
        let viewModel = balanceViewModelFactory.amountFromValue(balance).value(for: selectedLocale)
        view?.didReceiveTransferable(viewModel: viewModel)
    }

    func provideAmountInputViewModel() {
        let inputAmount = getInputAmount()
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveInput(viewModel: viewModel)
    }

    func provideAssetViewModel() {
        let balance = assetBalance?.transferable.decimal(precision: chainAsset.asset.precision) ?? 0
        let inputAmount = getInputAmount() ?? 0
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    override func getInputAmount() -> Decimal? {
        guard let inputResult = inputResult else {
            return nil
        }
        switch inputResult {
        case .rate:
            let fee = fee?.decimal(precision: chainAsset.asset.precision) ?? 0
            let availableAmountDecimal = assetBalance?.transferable.decimal(precision: chainAsset.asset.precision) ?? 0
            return inputResult.absoluteValue(from: availableAmountDecimal - fee)
        case let .absolute(inputValue):
            return inputResult.absoluteValue(from: inputValue)
        }
    }

    override func updateView() {
        provideAmountInputViewModel()
        provideAssetViewModel()
        provideTransferrableBalance()
        provideFee()
        provideHints()
    }

    override func provideHints() {
        let hints = hintsViewModelFactory.createHints(
            rewards: claimableRewards,
            locale: selectedLocale
        )
        view?.didReceiveHints(viewModel: hints)
    }

    override func provideFee() {
        guard let fee = fee?.decimal(precision: chainAsset.asset.precision) else {
            view?.didReceiveFee(viewModel: nil)
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: price).value(for: selectedLocale)

        view?.didReceiveFee(viewModel: viewModel)
    }

    override func getInputAmountInPlank() -> BigUInt? {
        guard let decimalAmount = getInputAmount() else {
            return nil
        }

        return decimalAmount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )
    }

    override func didReceive(assetBalance: AssetBalance?) {
        super.didReceive(assetBalance: assetBalance)

        provideAssetViewModel()
        provideTransferrableBalance()
        updateAmountInputViewModelIfNeeded()
    }

    override func didReceive(stakingLedger: StakingLedger?) {
        super.didReceive(stakingLedger: stakingLedger)

        provideAssetViewModel()
        updateAmountInputViewModelIfNeeded()
    }

    override func didReceive(price: PriceData?) {
        super.didReceive(price: price)

        provideAmountInputViewModel()
        provideAssetViewModel()
        provideTransferrableBalance()
        provideFee()
    }

    func updateAmountInputViewModelIfNeeded() {
        if case .rate = inputResult {
            provideAmountInputViewModel()
        }
    }
}

extension NominationPoolBondMorePresenter: NominationPoolBondMorePresenterProtocol {
    func setup() {
        interactor?.setup()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAmountInputViewModel()
        provideAssetViewModel()
        refreshFee()
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { AmountInputResult.absolute($0) }

        provideAssetViewModel()
        refreshFee()
    }

    func proceed() {
        let validators = getValidations()

        DataValidationRunner(
            validators: validators
        ).runValidation { [weak self] in
            self?.wireframe?.showConfirm(from: self?.view)
        }
    }
}
