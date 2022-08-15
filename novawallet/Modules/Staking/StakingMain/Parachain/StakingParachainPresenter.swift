import Foundation

final class StakingParachainPresenter {
    weak var view: StakingMainViewProtocol?

    let interactor: StakingParachainInteractorInputProtocol
    let wireframe: StakingParachainWireframeProtocol
    let logger: LoggerProtocol

    let stateMachine: ParaStkStateMachineProtocol
    let networkInfoViewModelFactory: ParaStkNetworkInfoViewModelFactoryProtocol
    let stateViewModelFactory: ParaStkStateViewModelFactoryProtocol
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    init(
        interactor: StakingParachainInteractorInputProtocol,
        wireframe: StakingParachainWireframeProtocol,
        networkInfoViewModelFactory: ParaStkNetworkInfoViewModelFactoryProtocol,
        stateViewModelFactory: ParaStkStateViewModelFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.networkInfoViewModelFactory = networkInfoViewModelFactory
        self.stateViewModelFactory = stateViewModelFactory
        self.logger = logger
        self.priceAssetInfoFactory = priceAssetInfoFactory

        let stateMachine = ParachainStaking.StateMachine()
        self.stateMachine = stateMachine
        stateMachine.delegate = self
    }

    private func provideNetworkInfo() {
        let optCommonData = stateMachine.viewState { (state: ParachainStaking.BaseState) in
            state.commonData
        }

        if
            let networkInfo = optCommonData?.networkInfo,
            let chainAsset = optCommonData?.chainAsset {
            let viewModel = networkInfoViewModelFactory.createViewModel(
                from: networkInfo,
                duration: optCommonData?.stakingDuration,
                chainAsset: chainAsset,
                price: optCommonData?.price
            )
            view?.didRecieveNetworkStakingInfo(viewModel: viewModel)
        } else {
            view?.didRecieveNetworkStakingInfo(viewModel: nil)
        }
    }

    private func provideStateViewModel() {
        let stateViewModel = stateViewModelFactory.createViewModel(from: stateMachine.state)
        view?.didReceiveStakingState(viewModel: stateViewModel)
    }

    private func handleStakeMoreAction() {
        guard let delegator = stateMachine.viewState(
            using: { (state: ParachainStaking.DelegatorState) in state }
        ) else {
            return
        }

        let identities = delegator.delegations?.identitiesDict()

        wireframe.showStakeTokens(
            from: view,
            initialDelegator: delegator.delegatorState,
            initialScheduledRequests: delegator.scheduledRequests,
            delegationIdentities: identities
        )
    }

    private func handleUnstakeAction() {
        guard
            let delegator = stateMachine.viewState(
                using: { (state: ParachainStaking.DelegatorState) in state }
            ) else {
            return
        }

        let disabledCollators = delegator.scheduledRequests?.map(\.collatorId) ?? []
        let disabledSet = Set(disabledCollators)

        if delegator.delegatorState.delegations.contains(where: { !disabledSet.contains($0.owner) }) {
            wireframe.showUnstakeTokens(
                from: view,
                initialDelegator: delegator.delegatorState,
                initialScheduledRequests: delegator.scheduledRequests,
                delegationIdentities: delegator.delegations?.identitiesDict()
            )
        } else {
            guard let view = view else {
                return
            }

            wireframe.presentNoUnstakingOptions(view, locale: view.selectedLocale)
        }
    }

    private func presentRebond(for collatorId: AccountId, state: ParachainStaking.DelegatorState) {
        let identities = state.delegations?.identitiesDict()
        let identity = identities?[collatorId]

        wireframe.showRebondTokens(from: view, collatorId: collatorId, collatorIdentity: identity)
    }
}

extension StakingParachainPresenter: StakingMainChildPresenterProtocol {
    func setup() {
        view?.didReceiveStatics(viewModel: StakingParachainStatics())

        provideNetworkInfo()
        provideStateViewModel()

        interactor.setup()
    }

    func performMainAction() {
        wireframe.showStakeTokens(
            from: view,
            initialDelegator: nil,
            initialScheduledRequests: nil,
            delegationIdentities: nil
        )
    }

    func performRewardInfoAction() {
        guard
            let state = stateMachine.viewState(using: { (state: ParachainStaking.BaseState) in state }),
            let rewardCalculator = state.commonData.calculatorEngine,
            let asset = state.commonData.chainAsset?.asset else {
            return
        }

        let maxReward = rewardCalculator.calculateMaxReturn(for: .year)
        let avgReward = rewardCalculator.calculateAvgReturn(for: .year)

        wireframe.showRewardDetails(from: view, maxReward: maxReward, avgReward: avgReward, symbol: asset.symbol)
    }

    func performChangeValidatorsAction() {
        wireframe.showYourCollators(from: view)
    }

    func performSetupValidatorsForBondedAction() {}

    func performStakeMoreAction() {
        wireframe.showYourCollators(from: view)
    }

    func performRedeemAction() {
        wireframe.showRedeemTokens(from: view)
    }

    func performRebondAction() {
        guard
            let delegator = stateMachine.viewState(
                using: { (state: ParachainStaking.DelegatorState) in state }
            ),
            let chainAsset = delegator.commonData.chainAsset else {
            return
        }

        let delegationRequests = delegator.scheduledRequests ?? []

        guard let firstCollator = delegationRequests.first?.collatorId else {
            return
        }

        if delegationRequests.count > 1 {
            let identities = delegator.delegations?.identitiesDict()

            let accountDetailsViewModelFactory = ParaStkAccountDetailsViewModelFactory(
                chainAsset: chainAsset
            )

            let viewModels = accountDetailsViewModelFactory.createUnstakingViewModels(
                from: delegationRequests,
                identities: identities
            )

            wireframe.showUnstakingCollatorSelection(
                from: view,
                delegate: self,
                viewModels: viewModels,
                context: delegationRequests as NSArray
            )
        } else {
            presentRebond(for: firstCollator, state: delegator)
        }
    }

    func performAnalyticsAction() {}

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
}

extension StakingParachainPresenter: StakingParachainInteractorOutputProtocol {
    func didReceiveChainAsset(_ chainAsset: ChainAsset) {
        stateMachine.state.process(chainAsset: chainAsset)
    }

    func didReceiveAccount(_ account: MetaChainAccountResponse?) {
        stateMachine.state.process(account: account)
    }

    func didReceivePrice(_ price: PriceData?) {
        stateMachine.state.process(price: price)

        provideNetworkInfo()
    }

    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        stateMachine.state.process(balance: assetBalance)
    }

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?) {
        stateMachine.state.process(delegatorState: delegator)

        let optNewState = stateMachine.viewState { (state: ParachainStaking.DelegatorState) in
            state.delegatorState
        }

        guard let newState = optNewState else {
            stateMachine.state.process(scheduledRequests: nil)
            stateMachine.state.process(delegations: nil)
            return
        }

        interactor.fetchScheduledRequests()
        interactor.fetchDelegations(for: newState.collators())
    }

    func didReceiveScheduledRequests(_ requests: [ParachainStaking.DelegatorScheduledRequest]?) {
        stateMachine.state.process(scheduledRequests: requests ?? [])
    }

    func didReceiveDelegations(_ delegations: [CollatorSelectionInfo]) {
        stateMachine.state.process(delegations: delegations)
    }

    func didReceiveSelectedCollators(_ collatorsInfo: SelectedRoundCollators) {
        stateMachine.state.process(collatorsInfo: collatorsInfo)

        if let delegator = stateMachine.viewState(
            using: { (state: ParachainStaking.DelegatorState) in state }
        ) {
            let collatorIds = delegator.delegatorState.collators()
            interactor.fetchDelegations(for: collatorIds)
        }
    }

    func didReceiveRewardCalculator(_ calculator: ParaStakingRewardCalculatorEngineProtocol) {
        stateMachine.state.process(calculatorEngine: calculator)
    }

    func didReceiveNetworkInfo(_ networkInfo: ParachainStaking.NetworkInfo) {
        stateMachine.state.process(networkInfo: networkInfo)

        provideNetworkInfo()
    }

    func didReceiveStakingDuration(_ stakingDuration: ParachainStakingDuration) {
        stateMachine.state.process(stakingDuration: stakingDuration)

        provideNetworkInfo()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber?) {
        stateMachine.state.process(blockNumber: blockNumber)
    }

    func didReceiveRoundInfo(_ roundInfo: ParachainStaking.RoundInfo?) {
        stateMachine.state.process(roundInfo: roundInfo)
    }

    func didReceiveTotalReward(_ totalReward: TotalRewardItem?) {
        stateMachine.state.process(totalReward: totalReward)
    }

    func didReceiveError(_ error: Error) {
        logger.error("Did receive error: \(error)")
    }
}

extension StakingParachainPresenter: ParaStkStateMachineDelegate {
    func stateMachineDidChangeState(_: ParaStkStateMachineProtocol) {
        provideStateViewModel()
    }
}

extension StakingParachainPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let delegations = context as? [ParachainStaking.DelegatorScheduledRequest],
            let delegator = stateMachine.viewState(
                using: { (state: ParachainStaking.DelegatorState) in state }
            ) else {
            return
        }

        let collatorId = delegations[index].collatorId

        // make sure the tokes still can be rebonded after selection
        guard delegator.scheduledRequests?.first(where: { $0.collatorId == collatorId }) != nil else {
            return
        }

        presentRebond(for: collatorId, state: delegator)
    }
}
