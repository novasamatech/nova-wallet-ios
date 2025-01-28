import Foundation

final class MythosStakingDetailsPresenter {
    weak var view: StakingMainViewProtocol?
    let wireframe: MythosStakingDetailsWireframeProtocol
    let interactor: MythosStakingDetailsInteractorInputProtocol
    let viewModelFactory: MythosStkStateViewModelFactoryProtocol
    let logger: LoggerProtocol

    let stateMachine: MythosStakingStateMachineProtocol

    init(
        interactor: MythosStakingDetailsInteractorInputProtocol,
        wireframe: MythosStakingDetailsWireframeProtocol,
        viewModelFactory: MythosStkStateViewModelFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger

        let stateMachine = MythosStakingStateMachine()
        self.stateMachine = stateMachine

        stateMachine.delegate = self
    }
}

private extension MythosStakingDetailsPresenter {
    func provideStateViewModel() {
        let viewModel = viewModelFactory.createViewModel(from: stateMachine.state)
        view?.didReceiveStakingState(viewModel: viewModel)
    }
}

extension MythosStakingDetailsPresenter: StakingMainChildPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func performRedeemAction() {}

    func performRebondAction() {}

    func performClaimRewards() {}

    func performManageAction(_: StakingManageOption) {}

    func performAlertAction(_: StakingAlert) {
        // TODO: Implement in separate task
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
    }

    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: assetBalance))")

        stateMachine.state.process(balance: assetBalance)
    }

    func didReceiveStakingDetails(_ stakingDetails: MythosStakingDetails?) {
        logger.debug("Staking details: \(String(describing: stakingDetails))")

        stateMachine.state.process(stakingDetails: stakingDetails)
    }

    func didReceiveElectedCollators(_ collators: MythosSessionCollators) {
        logger.debug("Collators: \(String(describing: collators))")

        stateMachine.state.process(collatorsInfo: collators)
    }

    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards?) {
        logger.debug("Claimable rewards: \(String(describing: claimableRewards))")

        stateMachine.state.process(claimableRewards: claimableRewards)
    }

    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance?) {
        logger.debug("Frozen balance: \(String(describing: frozenBalance))")

        stateMachine.state.process(frozenBalance: frozenBalance)
    }

    func didReceiveTotalReward(_ totalReward: TotalRewardItem?) {
        logger.debug("Total reward: \(totalReward)")

        stateMachine.state.process(totalReward: totalReward)
    }
}
