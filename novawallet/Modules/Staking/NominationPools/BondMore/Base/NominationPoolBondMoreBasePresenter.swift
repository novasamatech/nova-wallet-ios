import Foundation
import BigInt
import SoraFoundation

class NominationPoolBondMoreBasePresenter: NominationPoolBondMoreBaseInteractorOutputProtocol {
    weak var view: NominationPoolBondMoreViewProtocol?
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
        wireframe: NominationPoolBondMoreWireframeProtocol,
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

    func provideHints() {
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

    func refreshFee() {
        let inputAmount = getInputAmountInPlank() ?? 0

        fee = nil

        provideFee()

        baseInteractor.estimateFee(for: inputAmount)
    }

    func spendingAmount() -> Decimal? {
        if let inputAmount = getInputAmount(),
           let fee = fee?.decimal(precision: chainAsset.asset.precision) {
            return inputAmount + fee
        } else {
            return nil
        }
    }

    func spendingAmountInPlank() -> BigUInt? {
        if let inputAmount = getInputAmountInPlank(),
           let fee = fee {
            return inputAmount + fee
        } else {
            return nil
        }
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
                spendingAmount: spendingAmount(),
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatorFactory.exsitentialDepositIsNotViolated(
                spendingAmount: spendingAmountInPlank(),
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
        case let .fetchFeeFailed:
            baseWireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case let .subscription:
            baseWireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.retrySubscriptions()
            }
        case let .claimableRewards:
            baseWireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.retryClaimableRewards()
            }
        case let .assetExistance:
            baseWireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.retryAssetExistance()
            }
        }
    }
}

extension NominationPoolBondMoreBasePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
