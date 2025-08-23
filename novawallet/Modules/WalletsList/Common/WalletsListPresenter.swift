import Foundation
import Operation_iOS
import BigInt
import Foundation_iOS

class WalletsListPresenter {
    weak var baseView: WalletsListViewProtocol?
    let baseWireframe: WalletsListWireframeProtocol
    let baseInteractor: WalletsListInteractorInputProtocol
    let viewModelFactory: WalletsListViewModelFactoryProtocol
    let logger: LoggerProtocol

    var viewModels: [WalletsListSectionViewModel] = []
    private(set) var chains: [ChainModel.Id: ChainModel] = [:]

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

    func filterIgnoredWallet(
        changes: [DataProviderChange<ManagedMetaAccountModel>]
    ) -> [DataProviderChange<ManagedMetaAccountModel>] {
        // we don't want display revoked delegated wallets

        changes.map { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                if newItem.info.delegatedAccountStatus() == .revoked {
                    return DataProviderChange<ManagedMetaAccountModel>.delete(
                        deletedIdentifier: newItem.identifier
                    )
                } else {
                    return change
                }

            case .delete:
                return change
            }
        }
    }

    func updateWallets(changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        let updatedChanges = filterIgnoredWallet(changes: changes)
        walletsList.apply(changes: updatedChanges)

        updateViewModels()
    }

    private func updateViewModels() {
        if let balancesCalculator = balancesCalculator {
            viewModels = viewModelFactory.createSectionViewModels(
                for: walletsList.allItems,
                balancesCalculator: balancesCalculator,
                chains: chains,
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
        updateWallets(changes: changes)
    }

    func didUpdateBalancesCalculator(_ calculator: BalancesCalculating) {
        balancesCalculator = calculator

        updateViewModels()
    }

    func didReceiveError(_ error: Error) {
        logger.error("Did receive error: \(error)")

        _ = baseWireframe.present(error: error, from: baseView, locale: selectedLocale)
    }

    func didReceiveChainChanges(_ changes: [DataProviderChange<ChainModel>]) {
        chains = changes.reduce(into: chains) { result, change in
            switch change {
            case let .insert(newItem):
                result[newItem.chainId] = newItem
            case let .update(newItem):
                result[newItem.chainId] = newItem
            case let .delete(deletedIdentifier):
                result[deletedIdentifier] = nil
            }
        }

        updateViewModels()
    }
}

extension WalletsListPresenter: Localizable {
    func applyLocalization() {
        if let view = baseView, view.isSetup {
            updateViewModels()
        }
    }
}
