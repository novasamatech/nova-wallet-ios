import Foundation
import RobinHood
import BigInt
import SoraFoundation

class WalletsListPresenter {
    weak var baseView: WalletsListViewProtocol?
    let baseWireframe: WalletsListWireframeProtocol
    let baseInteractor: WalletsListInteractorInputProtocol
    let viewModelFactory: WalletsListViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var viewModels: [WalletsListSectionViewModel] = []

    let walletsList: ListDifferenceCalculator<ManagedMetaAccountModel> = {
        let calculator = ListDifferenceCalculator<ManagedMetaAccountModel>(
            initialItems: []
        ) { item1, item2 in
            item1.order < item2.order
        }

        return calculator
    }()

    private var balancesCalculator: BalancesCalculating?

    init(
        baseInteractor: WalletsListInteractorInputProtocol,
        baseWireframe: WalletsListWireframeProtocol,
        viewModelFactory: WalletsListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.baseInteractor = baseInteractor
        self.baseWireframe = baseWireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func replaceViewModels(_ items: [WalletsListViewModel], section: Int) {
        let type = viewModels[section].type
        viewModels[section] = WalletsListSectionViewModel(type: type, items: items)
    }

    private func updateViewModels() {
        if let balancesCalculator = balancesCalculator {
            viewModels = viewModelFactory.createSectionViewModels(
                for: walletsList.allItems,
                balancesCalculator: balancesCalculator,
                locale: selectedLocale
            )
        }

        baseView?.didReload()
    }
}

extension WalletsListPresenter: WalletsListPresenterProtocol {
    func setup() {
        baseInteractor.setup()
    }

    func numberOfSections() -> Int {
        viewModels.count
    }

    func numberOfItems(in section: Int) -> Int {
        viewModels[section].items.count
    }

    func item(at index: Int, in section: Int) -> WalletsListViewModel {
        viewModels[section].items[index]
    }

    func section(at index: Int) -> WalletsListSectionViewModel {
        viewModels[index]
    }
}

extension WalletsListPresenter: WalletsListInteractorOutputProtocol {
    func didReceiveWalletsChanges(_ changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        walletsList.apply(changes: changes)

        updateViewModels()
    }

    func didUpdateBalancesCalculator(_ calculator: BalancesCalculating) {
        balancesCalculator = calculator

        updateViewModels()
    }

    func didReceiveError(_ error: Error) {
        logger.error("Did receive error: \(error)")

        _ = baseWireframe.present(error: error, from: baseView, locale: selectedLocale)
    }
}

extension WalletsListPresenter: Localizable {
    func applyLocalization() {
        if let view = baseView, view.isSetup {
            updateViewModels()
        }
    }
}
