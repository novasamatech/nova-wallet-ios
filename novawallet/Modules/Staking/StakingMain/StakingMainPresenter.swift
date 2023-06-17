import Foundation
import CommonWallet
import BigInt

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    let interactor: StakingMainInteractorInputProtocol

    let childPresenterFactory: StakingMainPresenterFactoryProtocol
    let viewModelFactory: StakingMainViewModelFactoryProtocol
    let stakingOption: Multistaking.ChainAssetOption
    let logger: LoggerProtocol?

    private var childPresenter: StakingMainChildPresenterProtocol?

    init(
        interactor: StakingMainInteractorInputProtocol,
        stakingOption: Multistaking.ChainAssetOption,
        childPresenterFactory: StakingMainPresenterFactoryProtocol,
        viewModelFactory: StakingMainViewModelFactoryProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.stakingOption = stakingOption
        self.childPresenterFactory = childPresenterFactory
        self.viewModelFactory = viewModelFactory
        self.logger = logger
    }

    private func provideMainViewModel() {
        let viewModel = viewModelFactory.createMainViewModel(chainAsset: stakingOption.chainAsset)

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - StakingMainPresenterProtocol

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        // setup default view state
        view?.didReceiveStakingState(viewModel: .undefined)

        provideMainViewModel()

        interactor.setup()
    }

    func performMainAction() {
        childPresenter?.performMainAction()
    }

    func performRewardInfoAction() {
        childPresenter?.performRewardInfoAction()
    }

    func performChangeValidatorsAction() {
        childPresenter?.performChangeValidatorsAction()
    }

    func performSetupValidatorsForBondedAction() {
        childPresenter?.performSetupValidatorsForBondedAction()
    }

    func performStakeMoreAction() {
        childPresenter?.performStakeMoreAction()
    }

    func performRedeemAction() {
        childPresenter?.performRedeemAction()
    }

    func performRebondAction() {
        childPresenter?.performRebondAction()
    }

    func performRebag() {
        childPresenter?.performRebag()
    }

    func networkInfoViewDidChangeExpansion(isExpanded: Bool) {
        interactor.saveNetworkInfoViewExpansion(isExpanded: isExpanded)
    }

    func performManageAction(_ action: StakingManageOption) {
        childPresenter?.performManageAction(action)
    }
}

extension StakingMainPresenter: StakingMainInteractorOutputProtocol {
    func didReceiveExpansion(_ isExpanded: Bool) {
        view?.expandNetworkInfoView(isExpanded)
    }
}
