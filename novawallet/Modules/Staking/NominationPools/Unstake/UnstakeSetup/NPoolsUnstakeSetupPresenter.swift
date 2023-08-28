import Foundation
import SoraFoundation
import BigInt

final class NPoolsUnstakeSetupPresenter: NPoolsUnstakeBasePresenter {
    weak var view: NPoolsUnstakeSetupViewProtocol?

    var wireframe: NPoolsUnstakeSetupWireframeProtocol? {
        baseWireframe as? NPoolsUnstakeSetupWireframeProtocol
    }

    var interactor: NPoolsUnstakeSetupInteractorInputProtocol? {
        baseInteractor as? NPoolsUnstakeSetupInteractorInputProtocol
    }

    private var inputResult: AmountInputResult?

    init(
        interactor: NPoolsUnstakeSetupInteractorInputProtocol,
        wireframe: NPoolsUnstakeSetupWireframeProtocol,
        chainAsset: ChainAsset,
        hintsViewModelFactory: NPoolsUnstakeHintsFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        super.init(
            baseInteractor: interactor,
            baseWireframe: wireframe,
            chainAsset: chainAsset,
            hintsViewModelFactory: hintsViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatorFactory: dataValidatorFactory,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    func provideAmountInputViewModel() {
        let stakedDecimal = getStakedAmount() ?? 0
        let inputAmount = inputResult?.absoluteValue(from: stakedDecimal)

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveInput(viewModel: viewModel)
    }

    func provideAssetViewModel() {
        let stakedAmount = getStakedAmount() ?? 0
        let inputAmount = inputResult?.absoluteValue(from: stakedAmount) ?? 0
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: stakedAmount,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    func provideTransferrableBalance() {
        guard let balance = assetBalance?.transferable.decimal(precision: chainAsset.asset.precision) else {
            view?.didReceiveTransferable(viewModel: nil)
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            balance,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveTransferable(viewModel: viewModel)
    }

    func updateAfterStakeAmountChange() {
        provideAssetViewModel()

        if case .rate = inputResult {
            provideAmountInputViewModel()
        }
    }

    // MARK: Subsclass

    override func updateView() {
        provideAmountInputViewModel()
        provideAssetViewModel()
        provideFee()
        provideHints()
    }

    override func provideHints() {
        let hints = hintsViewModelFactory.createHints(
            stakingDuration: stakingDuration,
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

    override func getInputAmount() -> Decimal? {
        let stakedDecimal = getStakedAmount() ?? 0
        return inputResult?.absoluteValue(from: stakedDecimal)
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

        provideTransferrableBalance()
    }

    override func didReceive(poolMember: NominationPools.PoolMember?) {
        super.didReceive(poolMember: poolMember)

        updateAfterStakeAmountChange()
    }

    override func didReceive(bondedPool: NominationPools.BondedPool?) {
        super.didReceive(bondedPool: bondedPool)

        updateAfterStakeAmountChange()
    }

    override func didReceive(stakingLedger: StakingLedger?) {
        super.didReceive(stakingLedger: stakingLedger)

        updateAfterStakeAmountChange()
    }

    override func didReceive(price: PriceData?) {
        super.didReceive(price: price)

        provideAssetViewModel()
        provideTransferrableBalance()
        provideFee()
    }
}

extension NPoolsUnstakeSetupPresenter: NPoolsUnstakeSetupPresenterProtocol {
    func setup() {
        updateView()

        interactor?.setup()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideAssetViewModel()
        refreshFee()
    }

    func updateAmount(_ newValue: Decimal?) {
        inputResult = newValue.map { AmountInputResult.absolute($0) }

        provideAmountInputViewModel()

        provideAssetViewModel()
        refreshFee()
    }

    func proceed() {
        let validators = getValidations()

        DataValidationRunner(
            validators: validators
        ).runValidation { [weak self] in
            guard let unstakingAmount = self?.getInputAmount() else {
                return
            }

            self?.wireframe?.showConfirm(from: self?.view, amount: unstakingAmount)
        }
    }
}

extension NPoolsUnstakeSetupPresenter: NPoolsUnstakeSetupInteractorOutputProtocol {}
