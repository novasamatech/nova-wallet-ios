import Foundation
import SoraFoundation

final class StakingMoreOptionsPresenter {
    weak var view: StakingMoreOptionsViewProtocol?
    let wireframe: StakingMoreOptionsWireframeProtocol
    let viewModelFactory: StakingMoreOptionsViewModelFactoryProtocol
    let interactor: StakingMoreOptionsInteractorInputProtocol
    let logger: LoggerProtocol

    private var moreOptions: [StakingDashboardItemModel] = []
    private var dApps: [DApp] = []

    init(
        interactor: StakingMoreOptionsInteractorInputProtocol,
        viewModelFactory: StakingMoreOptionsViewModelFactoryProtocol,
        wireframe: StakingMoreOptionsWireframeProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
        self.wireframe = wireframe
        self.logger = logger
    }

    private func provideDAppViewModel(dApps: [DApp]) {
        let viewModels = dApps.map(viewModelFactory.createDAppModel)
        view?.didReceive(dAppModels: viewModels)
    }

    private func provideMoreOptionsViewModel(moreOptions: [StakingDashboardItemModel]) {
        let viewModels = moreOptions.map {
            self.viewModelFactory.createStakingViewModel(for: $0, locale: selectedLocale)
        }
        view?.didReceive(moreOptionsModels: viewModels)
    }
}

extension StakingMoreOptionsPresenter: StakingMoreOptionsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectOption(at index: Int) {
        guard let option = moreOptions[safe: index] else {
            return
        }
        // TODO: navigation
    }

    func selectDApp(at index: Int) {
        guard let dApp = dApps[safe: index] else {
            return
        }
        wireframe.showBrowser(from: view, for: dApp)
    }
}

extension StakingMoreOptionsPresenter: StakingMoreOptionsInteractorOutputProtocol {
    func didReceive(dAppsResult: Result<DAppList, Error>?) {
        switch dAppsResult {
        case let .success(list):
            dApps = list.dApps
            provideDAppViewModel(dApps: list.dApps)
        case let .failure(error):
            logger.error(error.localizedDescription)
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeDAppsSubscription()
            }
        case .none:
            break
        }
    }

    func didReceive(moreOptions: [StakingDashboardItemModel]) {
        self.moreOptions = moreOptions
        provideMoreOptionsViewModel(moreOptions: moreOptions)
    }
}

extension StakingMoreOptionsPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            didReceive(moreOptions: moreOptions)
        }
    }
}
