import Foundation
import BigInt
import SoraFoundation

class NPoolsUnstakeBasePresenter: NPoolsUnstakeBaseInteractorOutputProtocol {
    weak var baseView: ControllerBackedProtocol?

    let baseWireframe: NPoolsUnstakeBaseWireframeProtocol
    let baseInteractor: NPoolsUnstakeBaseInteractorInputProtocol
    let chainAsset: ChainAsset
    let hintsViewModelFactory: NPoolsUnstakeHintsFactoryProtocol
    let dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol

    var assetBalance: AssetBalance?
    var poolMember: NominationPools.PoolMember?
    var bondedPool: NominationPools.BondedPool?
    var stakingLedger: StakingLedger?
    var stakingDuration: StakingDuration?
    var eraCountdown: EraCountdown?
    var claimableRewards: BigUInt?
    var minStake: BigUInt?
    var price: PriceData?
    var unstakingLimits: NominationPools.UnstakeLimits?
    var fee: BigUInt?

    init(
        baseInteractor: NPoolsUnstakeBaseInteractorInputProtocol,
        baseWireframe: NPoolsUnstakeBaseWireframeProtocol,
        chainAsset: ChainAsset,
        hintsViewModelFactory: NPoolsUnstakeHintsFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.baseInteractor = baseInteractor
        self.baseWireframe = baseWireframe
        self.chainAsset = chainAsset
        self.hintsViewModelFactory = hintsViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatorFactory = dataValidatorFactory
        self.logger = logger
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

    func getStakedAmountInPlank() -> BigUInt? {
        guard
            let stakingLedger = stakingLedger,
            let bondedPool = bondedPool,
            let poolMember = poolMember else {
            return nil
        }

        return NominationPools.pointsToBalance(
            for: poolMember.points,
            totalPoints: bondedPool.points,
            poolBalance: stakingLedger.active
        )
    }

    func getStakedAmount() -> Decimal? {
        getStakedAmountInPlank()?.decimal(precision: chainAsset.asset.precision)
    }

    func getValidations() -> [DataValidating] {
        [
            dataValidatorFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) { [weak self] in
                self?.refreshFee()
            },
            dataValidatorFactory.canUnstake(
                for: getInputAmount() ?? 0,
                stakedAmountInPlank: getStakedAmountInPlank(),
                chainAsset: chainAsset,
                locale: selectedLocale
            ),
            dataValidatorFactory.canPayFeeInPlank(
                balance: assetBalance?.transferable,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatorFactory.hasLedgerUnstakeSpace(
                for: stakingLedger,
                limits: unstakingLimits,
                eraCountdown: eraCountdown,
                locale: selectedLocale
            ),
            dataValidatorFactory.hasPoolMemberUnstakeSpace(
                for: poolMember,
                limits: unstakingLimits,
                eraCountdown: eraCountdown,
                locale: selectedLocale
            ),
            dataValidatorFactory.minStakeNotCrossed(
                for: getInputAmount() ?? 0,
                stakedAmountInPlank: getStakedAmountInPlank(),
                minStake: minStake,
                chainAsset: chainAsset,
                locale: selectedLocale
            )
        ]
    }

    func getUnstakingPoints() -> BigUInt? {
        guard
            let stakingLedger = stakingLedger,
            let bondedPool = bondedPool else {
            return nil
        }

        let inputAmount = getInputAmountInPlank() ?? 0

        return NominationPools.balanceToPoints(
            for: inputAmount,
            totalPoints: bondedPool.points,
            poolBalance: stakingLedger.active
        )
    }

    func refreshFee() {
        guard let unstakingPoints = getUnstakingPoints() else {
            return
        }

        fee = nil

        provideFee()

        baseInteractor.estimateFee(for: unstakingPoints)
    }

    // MARK: Unstake Base Interactor Output

    func didReceive(assetBalance: AssetBalance?) {
        logger.debug("Asset balance: \(String(describing: assetBalance))")

        self.assetBalance = assetBalance
    }

    func didReceive(poolMember: NominationPools.PoolMember?) {
        logger.debug("Pool member: \(String(describing: poolMember))")

        let shouldRefreshFee = poolMember?.points != self.poolMember?.points

        self.poolMember = poolMember
        provideHints()

        if shouldRefreshFee {
            refreshFee()
        }
    }

    func didReceive(bondedPool: NominationPools.BondedPool?) {
        logger.debug("Bonded pool: \(String(describing: bondedPool))")

        let shouldRefreshFee = bondedPool?.points != self.bondedPool?.points

        self.bondedPool = bondedPool

        if shouldRefreshFee {
            refreshFee()
        }
    }

    func didReceive(stakingLedger: StakingLedger?) {
        logger.debug("Staking ledger: \(String(describing: stakingLedger))")

        let shouldRefreshFee = stakingLedger?.active != self.stakingLedger?.active

        self.stakingLedger = stakingLedger

        if shouldRefreshFee {
            refreshFee()
        }
    }

    func didReceive(stakingDuration: StakingDuration) {
        logger.debug("Staking duration: \(stakingDuration)")

        self.stakingDuration = stakingDuration

        provideHints()
    }

    func didReceive(eraCountdown: EraCountdown) {
        logger.debug("Era countdown: \(eraCountdown)")

        self.eraCountdown = eraCountdown
    }

    func didReceive(claimableRewards: BigUInt?) {
        logger.debug("Claimable rewards: \(String(describing: claimableRewards))")

        self.claimableRewards = claimableRewards

        provideHints()
    }

    func didReceive(minStake: BigUInt?) {
        logger.debug("Min stake: \(String(describing: minStake))")

        self.minStake = minStake
    }

    func didReceive(price: PriceData?) {
        logger.debug("Price: \(String(describing: price))")

        self.price = price
    }

    func didReceive(unstakingLimits: NominationPools.UnstakeLimits) {
        logger.debug("Unstaking limits: \(unstakingLimits)")

        self.unstakingLimits = unstakingLimits
    }

    func didReceive(fee: BigUInt?) {
        logger.debug("Fee: \(String(describing: fee))")

        self.fee = fee

        provideFee()
    }

    func didReceive(error: NPoolsUnstakeBaseError) {
        logger.error("Error: \(error)")

        switch error {
        case .subscription:
            baseWireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.retrySubscriptions()
            }
        case .stakingDuration:
            baseWireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.retryStakingDuration()
            }
        case .eraCountdown:
            baseWireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.retryEraCountdown()
            }
        case .claimableRewards:
            baseWireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.retryClaimableRewards()
            }
        case .unstakeLimits:
            baseWireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.baseInteractor.retryUnstakeLimits()
            }
        case .fee:
            baseWireframe.presentFeeStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        }
    }
}

extension NPoolsUnstakeBasePresenter: Localizable {
    func applyLocalization() {
        if let view = baseView, view.isSetup {
            updateView()
        }
    }
}
