import Foundation

final class MythosStakingDetailsPresenter {
    weak var view: StakingMainViewProtocol?
    let wireframe: MythosStakingDetailsWireframeProtocol
    let interactor: MythosStakingDetailsInteractorInputProtocol
    let logger: LoggerProtocol

    let stateMachine: MythosStakingStateMachineProtocol

    init(
        interactor: MythosStakingDetailsInteractorInputProtocol,
        wireframe: MythosStakingDetailsWireframeProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        let stateMachine = MythosStakingStateMachine()
        self.stateMachine = stateMachine

        stateMachine.delegate = self
    }
}

private extension MythosStakingDetailsPresenter {
    func provideStateViewModel() {}
}

extension MythosStakingDetailsPresenter: StakingMainChildPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func performRedeemAction() {}

    func performRebondAction() {}

    func performClaimRewards() {}

    func performManageAction(_: StakingManageOption) {}

    func performAlertAction(_: StakingAlert) {}

    func selectPeriod(_: StakingRewardFiltersPeriod) {}
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

    func didReceiveRewardCalculator(_ calculator: CollatorStakingRewardCalculatorEngineProtocol) {
        logger.debug("Rewards Calculator: \(String(describing: calculator))")

        stateMachine.state.process(calculatorEngine: calculator)
    }

    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards?) {
        logger.debug("Claimable rewards: \(String(describing: claimableRewards))")

        stateMachine.state.process(claimableRewards: claimableRewards)
    }

    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance?) {
        logger.debug("Frozen balance: \(String(describing: frozenBalance))")

        stateMachine.state.process(frozenBalance: frozenBalance)
    }
}
