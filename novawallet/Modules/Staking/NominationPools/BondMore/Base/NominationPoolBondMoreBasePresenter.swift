import Foundation
import BigInt
import SoraFoundation

class NominationPoolBondMoreBasePresenter: NominationPoolBondMoreBaseInteractorOutputProtocol {
    weak var baseView: NominationPoolBondMoreBaseViewProtocol?
    let baseWireframe: NominationPoolBondMoreBaseWireframeProtocol
    let baseInteractor: NominationPoolBondMoreBaseInteractorInputProtocol

    let chainAsset: ChainAsset
    let hintsViewModelFactory: NominationPoolsBondMoreHintsFactoryProtocol
    let logger: LoggerProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol

    var assetBalance: AssetBalance?
    var poolMember: NominationPools.PoolMember?
    var bondedPool: NominationPools.BondedPool?
    var price: PriceData?
    var fee: BigUInt?
    var claimableRewards: BigUInt?
    var assetBalanceExistance: AssetBalanceExistence?

    init(
        interactor: NominationPoolBondMoreBaseInteractorInputProtocol,
        wireframe: NominationPoolBondMoreBaseWireframeProtocol,
        chainAsset: ChainAsset,
        hintsViewModelFactory: NominationPoolsBondMoreHintsFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        baseInteractor = interactor
        baseWireframe = wireframe
        self.logger = logger
        self.chainAsset = chainAsset
        self.hintsViewModelFactory = hintsViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatorFactory = dataValidatorFactory
        self.localizationManager = localizationManager
    }

    func updateView() {
        fatalError("Must be overriden by subsclass")
    }

    func provideFee() {
        fatalError("Must be overriden by subsclass")
    }

    func getInputAmount() -> Decimal? {
        fatalError("Must be overriden by subsclass")
    }

    func getInputAmountInPlank() -> BigUInt? {
        fatalError("Must be overriden by subsclass")
    }

    func provideHints() {
        let hints = hintsViewModelFactory.createHints(
            rewards: claimableRewards,
            locale: selectedLocale
        )

        baseView?.didReceiveHints(viewModel: hints)
    }

    func refreshFee() {
        let inputAmount = getInputAmountInPlank() ?? 0

        fee = nil

        provideFee()

        baseInteractor.estimateFee(for: inputAmount)
    }

    func getSpendingAmountInPlank() -> BigUInt? {
        guard let inputAmount = getInputAmountInPlank(),
              let fee = fee else {
            return nil
        }
        return inputAmount + fee
    }

    func getValidations() -> [DataValidating] {
        let baseValidators = [
            dataValidatorFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) { [weak self] in
                self?.refreshFee()
            },
            dataValidatorFactory.canSpendAmountInPlank(
                balance: assetBalance?.transferable,
                spendingAmount: getInputAmount(),
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatorFactory.canPayFeeSpendingAmountInPlank(
                balance: assetBalance?.transferable,
                fee: fee,
                spendingAmount: getInputAmount(),
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatorFactory.exsitentialDepositIsNotViolated(
                spendingAmount: getSpendingAmountInPlank(),
                totalAmount: assetBalance?.totalInPlank,
                minimumBalance: assetBalanceExistance?.minBalance,
                locale: selectedLocale
            )
        ]

        let poolValidators = [
            dataValidatorFactory.nominationPoolIsNotDestroing(
                pool: bondedPool,
                locale: selectedLocale
            ),
            dataValidatorFactory.nominationPoolIsNotFullyUnbonding(
                poolMember: poolMember,
                locale: selectedLocale
            )
        ]

        return baseValidators + poolValidators
    }

    // MARK: - NominationPoolBondMoreBaseInteractorOutputProtocol

    func didReceive(assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceive(poolMember: NominationPools.PoolMember?) {
        self.poolMember = poolMember
    }

    func didReceive(bondedPool: NominationPools.BondedPool?) {
        self.bondedPool = bondedPool
    }

    func didReceive(price: PriceData?) {
        self.price = price
    }

    func didReceive(fee: BigUInt?) {
        self.fee = fee

        provideFee()
    }

    func didReceive(claimableRewards: BigUInt?) {
        self.claimableRewards = claimableRewards

        provideHints()
    }

    func didReceive(assetBalanceExistance: AssetBalanceExistence?) {
        self.assetBalanceExistance = assetBalanceExistance
    }

    func didReceive(error: NominationPoolBondMoreError) {
        logger.error(error.localizedDescription)

        switch error {
        case .fetchFeeFailed:
            baseWireframe.presentFeeStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .subscription:
            baseWireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.retrySubscriptions()
            }
        case .claimableRewards:
            baseWireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.retryClaimableRewards()
            }
        case .assetExistance:
            baseWireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.retryAssetExistance()
            }
        }
    }
}

extension NominationPoolBondMoreBasePresenter: Localizable {
    func applyLocalization() {
        if baseView?.isSetup == true {
            updateView()
        }
    }
}
