import Foundation
import Foundation_iOS

final class StakingMoreOptionsPresenter {
    weak var view: StakingMoreOptionsViewProtocol?
    let wireframe: StakingMoreOptionsWireframeProtocol
    let viewModelFactory: StakingMoreOptionsViewModelFactoryProtocol
    let interactor: StakingMoreOptionsInteractorInputProtocol
    let logger: LoggerProtocol

    let metaId: MetaAccountModel.Id

    private var moreOptions: [StakingDashboardItemModel] = []
    private var dApps: [DApp] = []

    init(
        interactor: StakingMoreOptionsInteractorInputProtocol,
        viewModelFactory: StakingMoreOptionsViewModelFactoryProtocol,
        wireframe: StakingMoreOptionsWireframeProtocol,
        metaId: MetaAccountModel.Id,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
        self.wireframe = wireframe
        self.metaId = metaId
        self.logger = logger
        self.localizationManager = localizationManager
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
        view?.didReceive(dAppModels: viewModelFactory.createLoadingDAppModel())
        interactor.setup()
    }

    func selectOption(at index: Int) {
        guard let item = moreOptions[safe: index] else {
            return
        }

        switch item {
        case let .concrete(concrete):
            wireframe.showStartStaking(
                from: view,
                chainAsset: concrete.chainAsset,
                stakingType: concrete.stakingOption.type
            )
        case let .combined(combined):
            wireframe.showStartStaking(
                from: view,
                chainAsset: combined.chainAsset,
                stakingType: nil
            )
        }
    }

    func selectDApp(at index: Int) {
        guard let dApp = dApps[safe: index] else {
            return
        }

        wireframe.openBrowser(with: dApp.identifier)
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
