import Foundation
import BigInt
import SoraFoundation

class NPoolsUnstakeBasePresenter: NPoolsUnstakeBaseInteractorOutputProtocol {
    weak var baseView: ControllerBackedProtocol?

    let baseWireframe: NPoolsUnstakeBaseWireframeProtocol
    let baseInteractor: NPoolsUnstakeBaseInteractorInputProtocol
    let chainAsset: ChainAsset
    let hintsViewModelFactory: NPoolsUnstakeHintsFactoryProtocol
    let logger: LoggerProtocol

    var assetBalance: AssetBalance?
    var poolMember: NominationPools.PoolMember?
    var bondedPool: NominationPools.BondedPool?
    var subPools: NominationPools.SubPools?
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
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.baseInteractor = baseInteractor
        self.baseWireframe = baseWireframe
        self.chainAsset = chainAsset
        self.hintsViewModelFactory = hintsViewModelFactory
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

    func refreshFee() {
        guard
            let inputAmount = getInputAmountInPlank(),
            let stakingLedger = stakingLedger,
            let bondedPool = bondedPool else {
            return
        }

        fee = nil

        provideFee()

        let points = NominationPools.balanceToPoints(
            for: inputAmount,
            totalPoints: bondedPool.points,
            poolBalance: stakingLedger.active
        )

        baseInteractor.estimateFee(for: points)
    }

    // MARK: Unstake Base Interactor Output

    func didReceive(assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceive(poolMember: NominationPools.PoolMember?) {
        let shouldRefreshFee = poolMember?.points != self.poolMember?.points

        self.poolMember = poolMember
        provideHints()

        if shouldRefreshFee {
            refreshFee()
        }
    }

    func didReceive(bondedPool: NominationPools.BondedPool?) {
        let shouldRefreshFee = bondedPool?.points != self.bondedPool?.points

        self.bondedPool = bondedPool

        if shouldRefreshFee {
            refreshFee()
        }
    }

    func didReceive(subPools: NominationPools.SubPools?) {
        self.subPools = subPools
    }

    func didReceive(stakingLedger: StakingLedger?) {
        let shouldRefreshFee = stakingLedger?.active != self.stakingLedger?.active

        self.stakingLedger = stakingLedger

        if shouldRefreshFee {
            refreshFee()
        }
    }

    func didReceive(stakingDuration: StakingDuration) {
        self.stakingDuration = stakingDuration
    }

    func didReceive(eraCountdown: EraCountdown) {
        self.eraCountdown = eraCountdown
    }

    func didReceive(claimableRewards: BigUInt?) {
        self.claimableRewards = claimableRewards
    }

    func didReceive(minStake: BigUInt?) {
        self.minStake = minStake
    }

    func didReceive(price: PriceData?) {
        self.price = price
    }

    func didReceive(unstakingLimits: NominationPools.UnstakeLimits) {
        self.unstakingLimits = unstakingLimits
    }

    func didReceive(fee: BigUInt?) {
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
