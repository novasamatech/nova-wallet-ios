import BigInt
import SoraFoundation

final class NominationPoolBondMoreSetupPresenter: NominationPoolBondMoreBasePresenter {
    weak var view: NominationPoolBondMoreSetupViewProtocol? {
        baseView as? NominationPoolBondMoreSetupViewProtocol
    }

    var wireframe: NominationPoolBondMoreSetupWireframeProtocol? {
        baseWireframe as? NominationPoolBondMoreSetupWireframeProtocol
    }

    var interactor: NominationPoolBondMoreSetupInteractorInputProtocol? {
        baseInteractor as? NominationPoolBondMoreSetupInteractorInputProtocol
    }

    private var inputResult: AmountInputResult?

    init(
        interactor: NominationPoolBondMoreSetupInteractorInputProtocol,
        wireframe: NominationPoolBondMoreSetupWireframeProtocol,
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
        let fee = fee?.decimal(precision: chainAsset.asset.precision) ?? 0
        let transferable = assetBalance?.transferable.decimal(precision: chainAsset.asset.precision) ?? 0
        let total = assetBalance?.totalInPlank.decimal(precision: chainAsset.asset.precision) ?? 0
        let existentialDeposit = assetBalanceExistance?.minBalance.decimal(precision: chainAsset.asset.precision) ?? 0
        let value = max(min(transferable - fee, total - fee - existentialDeposit), 0)
        return inputResult.absoluteValue(from: value)
    }

    override func updateView() {
        provideAmountInputViewModel()
        provideAssetViewModel()
        provideTransferrableBalance()
        provideFee()
        provideHints()
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
        provideAmountInputViewModel()
    }

    override func didReceive(price: PriceData?) {
        super.didReceive(price: price)

        provideAmountInputViewModel()
        provideAssetViewModel()
        provideTransferrableBalance()
        provideFee()
    }

    override func didReceive(assetBalanceExistance: AssetBalanceExistence?) {
        super.didReceive(assetBalanceExistance: assetBalanceExistance)

        provideAmountInputViewModel()
    }
}

extension NominationPoolBondMoreSetupPresenter: NominationPoolBondMoreSetupPresenterProtocol {
    func setup() {
        interactor?.setup()
        refreshFee()
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
            guard let amount = self?.getInputAmount() else {
                return
            }
            self?.wireframe?.showConfirm(from: self?.view, amount: amount)
        }
    }
}
