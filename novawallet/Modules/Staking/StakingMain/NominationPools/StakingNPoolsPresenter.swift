import Foundation
import SoraFoundation
import BigInt

final class StakingNPoolsPresenter {
    weak var view: StakingMainViewProtocol?

    let interactor: StakingNPoolsInteractorInputProtocol
    let wireframe: StakingNPoolsWireframeProtocol
    let infoViewModelFactory: NetworkInfoViewModelFactoryProtocol
    let chainAsset: ChainAsset
    let logger: LoggerProtocol

    private var totalActiveStake: BigUInt?
    private var minStake: BigUInt?
    private var activeEra: ActiveEraInfo?
    private var poolMember: NominationPools.PoolMember?
    private var bondedPool: NominationPools.BondedPool?
    private var poolLedger: StakingLedger?
    private var poolNomination: Nomination?
    private var poolBondedAccountId: AccountId?
    private var activePools: Set<NominationPools.PoolId>?
    private var duration: StakingDuration?
    private var priceData: PriceData?

    init(
        interactor: StakingNPoolsInteractorInputProtocol,
        wireframe: StakingNPoolsWireframeProtocol,
        infoViewModelFactory: NetworkInfoViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.infoViewModelFactory = infoViewModelFactory
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

    private func updateView() {
        provideStatics()
        provideStakingInfo()
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

    func selectPeriod(_: StakingRewardFiltersPeriod) {
        // TODO: Implement in task for rewards
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
        self.activeEra = activeEra
    }

    func didReceive(poolLedger: StakingLedger?) {
        self.poolLedger = poolLedger
    }

    func didReceive(poolNomination: Nomination?) {
        self.poolNomination = poolNomination
    }

    func didReceive(poolMember: NominationPools.PoolMember?) {
        self.poolMember = poolMember
    }

    func didReceive(bondedPool: NominationPools.BondedPool?) {
        self.bondedPool = bondedPool
    }

    func didReceive(poolBondedAccountId: AccountId) {
        self.poolBondedAccountId = poolBondedAccountId
    }

    func didReceive(activePools: Set<NominationPools.PoolId>) {
        self.activePools = activePools
    }

    func didReceive(price: PriceData?) {
        priceData = price

        provideStakingInfo()
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
