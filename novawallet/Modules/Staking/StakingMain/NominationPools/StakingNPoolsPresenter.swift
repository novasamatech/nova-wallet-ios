import Foundation
import SoraFoundation
import BigInt

final class StakingNPoolsPresenter {
    weak var view: StakingMainViewProtocol?

    let interactor: StakingNPoolsInteractorInputProtocol
    let wireframe: StakingNPoolsWireframeProtocol
    let infoViewModelFactory: NetworkInfoViewModelFactoryProtocol
    let stateViewModelFactory: StakingNPoolsViewModelFactoryProtocol
    let chainAsset: ChainAsset
    let logger: LoggerProtocol

    private var totalActiveStake: BigUInt?
    private var minStake: BigUInt?
    private var activeEra: ActiveEraInfo?
    private var poolMember: NominationPools.PoolMember?
    private var bondedPool: NominationPools.BondedPool?
    private var subPools: NominationPools.SubPools?
    private var poolLedger: StakingLedger?
    private var poolNomination: Nomination?
    private var poolBondedAccountId: AccountId?
    private var activePools: Set<NominationPools.PoolId>?
    private var duration: StakingDuration?
    private var claimableRewards: BigUInt?
    private var eraCountdown: EraCountdown?
    private var priceData: PriceData?
    private var totalRewardsFilter: StakingRewardFiltersPeriod?
    private var totalRewards: TotalRewardItem?

    init(
        interactor: StakingNPoolsInteractorInputProtocol,
        wireframe: StakingNPoolsWireframeProtocol,
        infoViewModelFactory: NetworkInfoViewModelFactoryProtocol,
        stateViewModelFactory: StakingNPoolsViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.infoViewModelFactory = infoViewModelFactory
        self.stateViewModelFactory = stateViewModelFactory
        self.chainAsset = chainAsset
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideStatics() {
        view?.didReceiveStatics(viewModel: StakingNominationPoolsStatics())
    }

    private func provideStakingInfo() {
        let params = NPoolsDetailsInfoParams(
            totalActiveStake: totalActiveStake,
            minStake: minStake,
            duration: duration
        )

        let viewModel = infoViewModelFactory.createNPoolsStakingInfoViewModel(
            for: params,
            chainAsset: chainAsset,
            priceData: priceData,
            locale: selectedLocale
        )

        view?.didRecieveNetworkStakingInfo(viewModel: viewModel)
    }

    private func provideState() {
        let params = StakingNPoolsViewModelParams(
            poolMember: poolMember,
            bondedPool: bondedPool,
            subPools: subPools,
            poolLedger: poolLedger,
            poolNomination: poolNomination,
            activePools: activePools,
            activeEra: activeEra,
            eraCountdown: eraCountdown,
            totalRewards: totalRewards,
            totalRewardsFilter: totalRewardsFilter,
            claimableRewards: claimableRewards
        )

        let viewModel = stateViewModelFactory.createState(for: params, chainAsset: chainAsset, price: priceData)

        view?.didReceiveStakingState(viewModel: viewModel)
    }

    private func updateView() {
        provideStatics()
        provideStakingInfo()
        provideState()
    }
}

extension StakingNPoolsPresenter: StakingMainChildPresenterProtocol {
    func setup() {
        updateView()
        interactor.setup()
    }

    func performRedeemAction() {
        wireframe.showRedeem(from: view)
    }

    func performRebondAction() {
        logger.warning("Not possible action for nomination pools")
    }

    func performClaimRewards() {
        wireframe.showClaimRewards(from: view)
    }

    func performManageAction(_ action: StakingManageOption) {
        switch action {
        case .stakeMore:
            wireframe.showStakeMore(from: view)
        case .unstake:
            wireframe.showUnstake(from: view)
        default:
            logger.warning("Unsupported action: \(action)")
        }
    }

    func performAlertAction(_: StakingAlert) {
        // TODO: Implement in task for alerts
    }

    func selectPeriod(_ filter: StakingRewardFiltersPeriod) {
        totalRewardsFilter = filter
        interactor.setupTotalRewards(filter: filter)

        provideState()
    }
}

extension StakingNPoolsPresenter: StakingNPoolsInteractorOutputProtocol {
    func didReceive(minStake: BigUInt?) {
        self.minStake = minStake

        provideStakingInfo()
    }

    func didReceive(duration: StakingDuration) {
        self.duration = duration

        provideStakingInfo()
    }

    func didReceive(totalActiveStake: BigUInt) {
        self.totalActiveStake = totalActiveStake

        provideStakingInfo()
    }

    func didReceive(activeEra: ActiveEraInfo?) {
        logger.debug("Active era: \(String(describing: activeEra))")

        self.activeEra = activeEra

        provideState()
    }

    func didReceive(poolLedger: StakingLedger?) {
        logger.debug("Pool Ledger: \(String(describing: poolLedger))")

        self.poolLedger = poolLedger

        provideState()
    }

    func didReceive(poolNomination: Nomination?) {
        logger.debug("Pool nomination: \(String(describing: poolNomination))")

        self.poolNomination = poolNomination

        provideState()
    }

    func didReceive(poolMember: NominationPools.PoolMember?) {
        logger.debug("Pool member: \(String(describing: poolMember))")

        self.poolMember = poolMember

        provideState()
    }

    func didReceive(bondedPool: NominationPools.BondedPool?) {
        logger.debug("Bonded pool: \(String(describing: bondedPool))")

        self.bondedPool = bondedPool

        provideState()
    }

    func didReceive(subPools: NominationPools.SubPools?) {
        logger.debug("SubPools: \(String(describing: subPools))")

        self.subPools = subPools

        provideState()
    }

    func didReceive(poolBondedAccountId: AccountId) {
        logger.debug("Pool account id: \(String(describing: poolBondedAccountId))")

        self.poolBondedAccountId = poolBondedAccountId
    }

    func didReceive(activePools: Set<NominationPools.PoolId>) {
        logger.debug("Active pools: \(String(describing: activePools.count))")

        self.activePools = activePools

        provideState()
    }

    func didReceive(eraCountdown: EraCountdown) {
        logger.debug("Era countdown: \(String(describing: eraCountdown))")

        self.eraCountdown = eraCountdown

        provideState()
    }

    func didReceive(price: PriceData?) {
        priceData = price

        provideStakingInfo()
        provideState()
    }

    func didRecieve(claimableRewards: BigUInt?) {
        logger.debug("Claimable rewards: \(String(describing: claimableRewards))")

        self.claimableRewards = claimableRewards

        provideState()
    }

    func didReceive(totalRewards: TotalRewardItem?) {
        logger.debug("Total rewards: \(String(describing: totalRewards))")

        self.totalRewards = totalRewards

        provideState()
    }

    func didReceive(error: StakingNPoolsError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .stateSetup:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.setup()
            }
        case .subscription:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .totalActiveStake:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryActiveStake()
            }
        case .stakingDuration:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryStakingDuration()
            }
        case .activePools:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryActivePools()
            }
        case .eraCountdown:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryEraCountdown()
            }
        case .claimableRewards:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryClaimableRewards()
            }
        case .totalRewards:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                if let filter = self?.totalRewardsFilter {
                    self?.interactor.setupTotalRewards(filter: filter)
                }
            }
        }
    }
}

extension StakingNPoolsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
