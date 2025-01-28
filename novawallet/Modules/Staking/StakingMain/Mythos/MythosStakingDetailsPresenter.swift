import Foundation

final class MythosStakingDetailsPresenter {
    weak var view: StakingMainViewProtocol?
    let wireframe: MythosStakingDetailsWireframeProtocol
    let interactor: MythosStakingDetailsInteractorInputProtocol
    let viewModelFactory: MythosStkStateViewModelFactoryProtocol
    let dataValidationFactory: MythosStakingValidationFactoryProtocol
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
        dataValidationFactory: MythosStakingValidationFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.dataValidationFactory = dataValidationFactory
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

    func ensureRewardsClaimed(_ successClosure: @escaping () -> Void) {
        guard let view else {
            return
        }

        let validator = DataValidationRunner(validators: [
            dataValidationFactory.noUnclaimedRewards(
                claimableRewards?.shouldClaim ?? false,
                claimAction: { [weak self] in
                    self?.wireframe.showClaimRewards(from: self?.view)
                },
                locale: view.selectedLocale
            )
        ])

        validator.runValidation {
            successClosure()
        }
    }

    func handleStakeMoreAction() {
        ensureRewardsClaimed { [weak self] in
            guard let self = self else { return }

            wireframe.showStakeTokens(
                from: view,
                initialDetails: stakingDetails
            )
        }
    }

    func handleUnstakeAction() {
        ensureRewardsClaimed { [weak self] in
            guard let self = self else { return }

            wireframe.showUnstakeTokens(
                from: view,
                initialDetails: stakingDetails
            )
        }
    }
}

extension MythosStakingDetailsPresenter: StakingMainChildPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func performRedeemAction() {}

    func performRebondAction() {}

    func performClaimRewards() {}

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
