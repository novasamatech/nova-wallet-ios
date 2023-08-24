import Foundation

import BigInt

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    let interactor: StakingMainInteractorInputProtocol
    let wireframe: StakingMainWireframeProtocol

    let childPresenterFactory: StakingMainPresenterFactoryProtocol
    let viewModelFactory: StakingMainViewModelFactoryProtocol
    let stakingOption: Multistaking.ChainAssetOption
    let logger: LoggerProtocol?

    private var childPresenter: StakingMainChildPresenterProtocol?
    private var period: StakingRewardFiltersPeriod?

    init(
        interactor: StakingMainInteractorInputProtocol,
        wireframe: StakingMainWireframeProtocol,
        stakingOption: Multistaking.ChainAssetOption,
        childPresenterFactory: StakingMainPresenterFactoryProtocol,
        viewModelFactory: StakingMainViewModelFactoryProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
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

        if childPresenter == nil, let view = view {
            childPresenter = childPresenterFactory.createPresenter(
                for: stakingOption,
                view: view
            )

            childPresenter?.setup()
        }

        interactor.setup()
    }

    func performRedeemAction() {
        childPresenter?.performRedeemAction()
    }

    func performRebondAction() {
        childPresenter?.performRebondAction()
    }

    func performClaimRewards() {
        childPresenter?.performClaimRewards()
    }

    func networkInfoViewDidChangeExpansion(isExpanded: Bool) {
        interactor.saveNetworkInfoViewExpansion(isExpanded: isExpanded)
    }

    func performManageAction(_ action: StakingManageOption) {
        childPresenter?.performManageAction(action)
    }

    func performAlertAction(_ alert: StakingAlert) {
        childPresenter?.performAlertAction(alert)
    }

    func performSelectedEntityAction() {
        childPresenter?.performSelectedEntityAction()
    }

    func selectPeriod() {
        wireframe.showPeriodSelection(
            from: view,
            initialState: period,
            delegate: self
        ) { [weak self] in
            self?.view?.didEditRewardFilters()
        }
    }
}

extension StakingMainPresenter: StakingMainInteractorOutputProtocol {
    func didReceiveExpansion(_ isExpanded: Bool) {
        view?.expandNetworkInfoView(isExpanded)
    }

    func didReceiveRewardFilter(_ period: StakingRewardFiltersPeriod) {
        self.period = period
        childPresenter?.selectPeriod(period)
    }
}

extension StakingMainPresenter: StakingRewardFiltersDelegate {
    func stackingRewardFilter(didSelectFilter filter: StakingRewardFiltersPeriod) {
        interactor.save(filter: filter)
    }
}
