import Foundation
import Foundation_iOS

final class SubtensorStakingDetailsPresenter {
    weak var view: StakingMainViewProtocol?
    let wireframe: SubtensorStakingDetailsWireframeProtocol
    let interactor: SubtensorStakingDetailsInteractorInputProtocol
    let viewModelFactory: SubtensorStkStateViewModelFactoryProtocol
    let selectedAccount: MetaChainAccountResponse
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol

    let stateMachine: SubtensorStakingStateMachineProtocol

    var stakingState: Multistaking.SubtensorStakingState? {
        stateMachine.viewState { (state: SubtensorStakingStakedState) in
            state.stakingState
        }
    }

    var commonData: SubtensorStakingCommonData? {
        stateMachine.viewState { (state: SubtensorStakingBaseState) in
            state.commonData
        }
    }

    init(
        interactor: SubtensorStakingDetailsInteractorInputProtocol,
        wireframe: SubtensorStakingDetailsWireframeProtocol,
        viewModelFactory: SubtensorStkStateViewModelFactoryProtocol,
        selectedAccount: MetaChainAccountResponse,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.selectedAccount = selectedAccount
        self.localizationManager = localizationManager
        self.logger = logger

        let stateMachine = SubtensorStakingStateMachine()
        self.stateMachine = stateMachine

        stateMachine.delegate = self
    }
}

private extension SubtensorStakingDetailsPresenter {
    func provideNetworkInfo() {
        if
            let commonData,
            let networkInfo = commonData.networkInfo,
            let chainAsset = commonData.chainAsset {
            let viewModel = viewModelFactory.createNetworkInfoViewModel(
                from: networkInfo,
                chainAsset: chainAsset,
                price: commonData.price,
                locale: localizationManager.selectedLocale
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

    func runIfOperationsAllowed(_ closure: () -> Void) {
        guard let view else {
            return
        }

        switch SubtensorOperationGate.verdict(for: selectedAccount.chainAccount.type) {
        case .allowed:
            closure()
        case let .signerNotSupported(type):
            wireframe.presentSignerNotSupportedView(from: view, type: type) {}
        case .noSigning:
            wireframe.presentNoSigningView(from: view) {}
        }
    }

    func maxRootPosition() -> SubtensorStakingPosition? {
        stakingState?.positions
            .filter { $0.netuid == SubtensorStakingPallet.rootNetuid }
            .max { $0.stakeAlpha < $1.stakeAlpha }
    }

    func handleStakeMoreAction() {
        runIfOperationsAllowed { [weak self] in
            self?.wireframe.showStakeTokens(
                from: self?.view,
                initialPosition: self?.maxRootPosition()
            )
        }
    }

    func handleUnstakeAction() {
        runIfOperationsAllowed { [weak self] in
            self?.wireframe.showUnstakeTokens(from: self?.view)
        }
    }

    func handlePositionListAction() {
        guard let stakingState, let commonData else {
            return
        }

        let viewModels = viewModelFactory.createPositionViewModels(
            for: stakingState,
            commonData: commonData
        )

        guard !viewModels.isEmpty else {
            return
        }

        wireframe.showPositionList(from: view, viewModels: viewModels)
    }
}

extension SubtensorStakingDetailsPresenter: StakingMainChildPresenterProtocol {
    func setup() {
        view?.didReceiveStatics(viewModel: StakingSubtensorStatics())

        provideNetworkInfo()

        interactor.setup()
    }

    func performRedeemAction() {
        // not applicable to Subtensor staking
    }

    func performRebondAction() {
        // not applicable to Subtensor staking
    }

    func performClaimRewards() {
        runIfOperationsAllowed { [weak self] in
            self?.wireframe.showClaimRewards(from: self?.view)
        }
    }

    func performManageAction(_ action: StakingManageOption) {
        switch action {
        case .stakeMore:
            handleStakeMoreAction()
        case .unstake:
            handleUnstakeAction()
        case .setupValidators, .changeValidators, .yourValidator:
            handlePositionListAction()
        default:
            break
        }
    }

    func performAlertAction(_ alert: StakingAlert) {
        switch alert {
        case .nominatorChangeValidators:
            handlePositionListAction()
        case .redeemUnbonded, .bondedSetValidators, .rebag, .waitingNextEra,
             .nominatorAllOversubscribed, .nominatorLowStake:
            // not applicable to Subtensor staking
            break
        }
    }

    func selectPeriod(_ filter: StakingRewardFiltersPeriod) {
        stateMachine.state.process(totalRewardFilter: filter)
        interactor.update(totalRewardFilter: filter)
    }
}

extension SubtensorStakingDetailsPresenter: SubtensorStakingStateMachineDelegate {
    func stateMachineDidChangeState(_: SubtensorStakingStateMachineProtocol) {
        provideStateViewModel()
    }
}

extension SubtensorStakingDetailsPresenter: SubtensorStakingDetailsInteractorOutputProtocol {
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

    func didReceivePositionsState(_ positionsState: Multistaking.SubtensorStakingState?) {
        logger.debug("Positions: \(String(describing: positionsState))")

        stateMachine.state.process(positionsState: positionsState)
    }

    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?) {
        logger.debug("Claimable: \(String(describing: claimable))")

        stateMachine.state.process(claimable: claimable)
    }

    func didReceiveDelegates(_ delegates: [SubtensorDelegate]) {
        logger.debug("Delegates: \(delegates.count)")

        stateMachine.state.process(delegates: delegates)
    }

    func didReceiveSubnetsInfo(_ subnetsInfo: SubtensorSubnetsInfo) {
        logger.debug("Subnets: \(subnetsInfo.subnets.count)")

        stateMachine.state.process(subnetsInfo: subnetsInfo)
    }

    func didReceiveNetworkInfo(_ networkInfo: SubtensorNetworkInfo) {
        logger.debug("Network info: \(networkInfo)")

        stateMachine.state.process(networkInfo: networkInfo)

        provideNetworkInfo()
    }

    func didReceiveTotalReward(_ totalReward: TotalRewardItem?) {
        logger.debug("Total reward: \(String(describing: totalReward))")

        stateMachine.state.process(totalReward: totalReward)
    }
}
