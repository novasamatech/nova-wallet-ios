import Foundation

final class MythosStakingDetailsPresenter {
    weak var view: StakingMainViewProtocol?
    let wireframe: MythosStakingDetailsWireframeProtocol
    let interactor: MythosStakingDetailsInteractorInputProtocol
    let viewModelFactory: MythosStkStateViewModelFactoryProtocol
    let networkInfoViewModelFactory: CollatorStkNetworkInfoViewModelFactoryProtocol
    let logger: LoggerProtocol

    let stateMachine: MythosStakingStateMachineProtocol

    var stakingDetails: MythosStakingDetails? {
        stateMachine.viewState { (state: MythosStakingDelegatorState) in
            state.stakingDetails
        }
    }

    var claimableRewards: MythosStakingClaimableRewards? {
        stateMachine.viewState { (state: MythosStakingBaseState) in
            state.commonData.claimableRewards
        }
    }

    init(
        interactor: MythosStakingDetailsInteractorInputProtocol,
        wireframe: MythosStakingDetailsWireframeProtocol,
        viewModelFactory: MythosStkStateViewModelFactoryProtocol,
        networkInfoViewModelFactory: CollatorStkNetworkInfoViewModelFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.networkInfoViewModelFactory = networkInfoViewModelFactory
        self.logger = logger

        let stateMachine = MythosStakingStateMachine()
        self.stateMachine = stateMachine

        stateMachine.delegate = self
    }
}

private extension MythosStakingDetailsPresenter {
    func provideNetworkInfo() {
        let optCommonData = stateMachine.viewState { (state: MythosStakingBaseState) in
            state.commonData
        }

        if
            let networkInfo = optCommonData?.networkInfo,
            let chainAsset = optCommonData?.chainAsset {
            let model = CollatorStkNetworkModel(
                totalStake: networkInfo.totalStake,
                minStake: networkInfo.minStake,
                activeDelegators: networkInfo.activeStakersCount,
                unstakingDuration: optCommonData?.duration?.unstaking
            )

            let viewModel = networkInfoViewModelFactory.createViewModel(
                from: model,
                chainAsset: chainAsset,
                price: optCommonData?.price,
                locale: view?.selectedLocale ?? Locale.current
            )

            view?.didRecieveNetworkStakingInfo(viewModel: viewModel)
        } else {
            view?.didRecieveNetworkStakingInfo(viewModel: NetworkStakingInfoViewModel.allLoading)
        }
    }

    func provideStateViewModel() {
        let viewModel = viewModelFactory.createViewModel(from: stateMachine.state)
        view?.didReceiveStakingState(viewModel: viewModel)
    }

    func handleStakeMoreAction() {
        wireframe.showStakeTokens(
            from: view,
            initialDetails: stakingDetails
        )
    }

    func handleUnstakeAction() {
        wireframe.showUnstakeTokens(from: view)
    }
}

extension MythosStakingDetailsPresenter: StakingMainChildPresenterProtocol {
    func setup() {
        view?.didReceiveStatics(viewModel: StakingParachainStatics())

        provideNetworkInfo()

        interactor.setup()
    }

    func performRedeemAction() {
        wireframe.showRedeemTokens(from: view)
    }

    func performRebondAction() {
        // not applicable to Mythos staking
    }

    func performClaimRewards() {
        wireframe.showClaimRewards(from: view)
    }

    func performManageAction(_ action: StakingManageOption) {
        switch action {
        case .stakeMore:
            handleStakeMoreAction()
        case .unstake:
            handleUnstakeAction()
        case .setupValidators, .changeValidators, .yourValidator:
            wireframe.showYourCollators(from: view)
        default:
            break
        }
    }

    func performAlertAction(_ alert: StakingAlert) {
        switch alert {
        case .redeemUnbonded:
            performRedeemAction()
        case .bondedSetValidators:
            handleStakeMoreAction()
        case .nominatorChangeValidators:
            wireframe.showYourCollators(from: view)
        case .rebag, .waitingNextEra, .nominatorAllOversubscribed, .nominatorLowStake:
            // not applicable to Mythos staking
            break
        }
    }

    func selectPeriod(_ filter: StakingRewardFiltersPeriod) {
        stateMachine.state.process(totalRewardFilter: filter)
        interactor.update(totalRewardFilter: filter)
    }
}

extension MythosStakingDetailsPresenter: MythosStakingStateMachineDelegate {
    func stateMachineDidChangeState(_: MythosStakingStateMachineProtocol) {
        provideStateViewModel()
    }
}

extension MythosStakingDetailsPresenter: MythosStakingDetailsInteractorOutputProtocol {
    func didReceiveAccount(_ account: MetaChainAccountResponse?) {
        logger.debug("Account: \(String(describing: account))")

        stateMachine.state.process(account: account)
    }

    func didReceiveChainAsset(_ chainAsset: ChainAsset?) {
        logger.debug("Chain asset: \(String(describing: chainAsset))")

        stateMachine.state.process(chainAsset: chainAsset)
    }

    func didReceivePrice(_ price: PriceData?) {
        logger.debug("Price: \(String(describing: price))")

        stateMachine.state.process(price: price)

        provideNetworkInfo()
    }

    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: assetBalance))")

        stateMachine.state.process(balance: assetBalance)
    }

    func didReceiveStakingDetails(_ stakingDetailsState: MythosStakingDetailsState) {
        logger.debug("Staking details: \(String(describing: stakingDetails))")

        stateMachine.state.process(stakingDetailsState: stakingDetailsState)
    }

    func didReceiveElectedCollators(_ collators: MythosSessionCollators) {
        logger.debug("Collators: \(String(describing: collators))")

        stateMachine.state.process(collatorsInfo: collators)
    }

    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards?) {
        logger.debug("Claimable rewards: \(String(describing: claimableRewards))")

        stateMachine.state.process(claimableRewards: claimableRewards)
    }

    func didReceiveReleaseQueue(_ releaseQueue: MythosStakingPallet.ReleaseQueue?) {
        logger.debug("Release queue: \(String(describing: releaseQueue))")

        stateMachine.state.process(releaseQueue: releaseQueue)
    }

    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance?) {
        logger.debug("Frozen balance: \(String(describing: frozenBalance))")

        stateMachine.state.process(frozenBalance: frozenBalance)
    }

    func didReceiveTotalReward(_ totalReward: TotalRewardItem?) {
        logger.debug("Total reward: \(String(describing: totalReward))")

        stateMachine.state.process(totalReward: totalReward)
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        logger.debug("Block: \(blockNumber)")

        stateMachine.state.process(blockNumber: blockNumber)
    }

    func didReceiveStakingDuration(_ stakingDuration: MythosStakingDuration) {
        logger.debug("Staking duration: \(stakingDuration)")

        stateMachine.state.process(duration: stakingDuration)

        provideNetworkInfo()
    }

    func didReceiveNetworkInfo(_ info: MythosStakingNetworkInfo) {
        logger.debug("Network info: \(info)")

        stateMachine.state.process(networkInfo: info)

        provideNetworkInfo()
    }
}
