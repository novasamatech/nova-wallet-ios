import Foundation
import Operation_iOS
import Foundation_iOS

final class StakingDashboardPresenter {
    weak var view: StakingDashboardViewProtocol?
    let wireframe: StakingDashboardWireframeProtocol
    let interactor: StakingDashboardInteractorInputProtocol
    let viewModelFactory: StakingDashboardViewModelFactoryProtocol
    let logger: LoggerProtocol

    private var lastResult: StakingDashboardBuilderResult?

    init(
        interactor: StakingDashboardInteractorInputProtocol,
        wireframe: StakingDashboardWireframeProtocol,
        viewModelFactory: StakingDashboardViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateStakingsView() {
        guard let result = lastResult else {
            return
        }

        switch result.changeKind {
        case .reload:
            reloadStakingView(using: result.model)
        case let .sync(syncChange):
            updateStakingView(using: result.model, syncChange: syncChange)
        }
    }

    private func reloadStakingView(using model: StakingDashboardModel) {
        let viewModel = viewModelFactory.createViewModel(from: model, locale: selectedLocale)
        view?.didReceiveStakings(viewModel: viewModel)
    }

    private func updateStakingView(
        using model: StakingDashboardModel,
        syncChange: StakingDashboardBuilderResult.SyncChange
    ) {
        let updateViewModel = viewModelFactory.createUpdateViewModel(
            from: model,
            syncChange: syncChange,
            locale: selectedLocale
        )

        view?.didReceiveUpdate(viewModel: updateViewModel)
    }
}

extension StakingDashboardPresenter: StakingDashboardPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectActiveStaking(at index: Int) {
        guard let option = lastResult?.model.active[index].stakingOption else {
            return
        }

        wireframe.showStakingDetails(from: view, option: option)
    }

    func selectInactiveStaking(at index: Int) {
        guard let item = lastResult?.model.inactive[index] else {
            return
        }

        wireframe.showStartStaking(from: view, chainAsset: item.chainAsset)
    }

    func selectMoreOptions() {
        wireframe.showMoreOptions(from: view)
    }

    func refresh() {
        interactor.refresh()
    }
}

extension StakingDashboardPresenter: StakingDashboardInteractorOutputProtocol {
    func didReceive(walletId: String) {
        lastResult = StakingDashboardBuilderResult(
            walletId: walletId,
            model: .init(),
            changeKind: .reload
        )

        updateStakingsView()
    }

    func didReceive(result: StakingDashboardBuilderResult) {
        guard lastResult?.walletId == result.walletId else {
            return
        }

        lastResult = result

        updateStakingsView()
    }

    func didReceive(error: StakingDashboardInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .balanceFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryBalancesSubscription()
            }
        case .priceFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryPricesSubscription()
            }
        case .stakingsFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryDashboardSubscription()
            }
        }
    }
}

extension StakingDashboardPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateStakingsView()
        }
    }
}
