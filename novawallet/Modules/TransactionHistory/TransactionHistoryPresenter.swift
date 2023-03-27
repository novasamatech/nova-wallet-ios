import Foundation
import SoraFoundation
import CommonWallet
import RobinHood

final class TransactionHistoryPresenter {
    weak var view: TransactionHistoryViewProtocol?
    let wireframe: TransactionHistoryWireframeProtocol
    let interactor: TransactionHistoryInteractorInputProtocol
    let viewModelFactory: TransactionHistoryViewModelFactory2Protocol
    let logger: LoggerProtocol?

    private var viewModel: [Date: [TransactionItemViewModel]] = [:]
    private var items: [String: TransactionHistoryItem] = [:]
    private var accountAddress: AccountAddress?
    private var filter: WalletHistoryFilter = .all

    private var state: State = .waitingCache {
        didSet {
            switch (oldValue, state) {
            case (_, .waitingCache):
                view?.startLoading()
            case (_, .loadingData):
                view?.startLoading()
            case (_, .filteringData):
                view?.startLoading()
            case (.loadingData, .dataLoaded):
                view?.stopLoading()
            case (.waitingCache, .cacheLoaded):
                view?.stopLoading()
            case (.filteringData, .dataFiltered):
                view?.stopLoading()
            default:
                break
            }
        }
    }

    enum State {
        case waitingCache
        case cacheLoaded
        case loadingData
        case dataLoaded
        case filteringData
        case dataFiltered

        var isLoading: Bool {
            [.waitingCache, .loadingData, .filteringData].contains(self)
        }
    }

    init(
        interactor: TransactionHistoryInteractorInputProtocol,
        wireframe: TransactionHistoryWireframeProtocol,
        viewModelFactory: TransactionHistoryViewModelFactory2Protocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func reloadView(
        items: [String: TransactionHistoryItem]
    ) {
        guard let view = view, let accountAddress = accountAddress else {
            return
        }
        let pageViewModels = viewModelFactory.createGroupModel(
            Array(items.values),
            address: accountAddress,
            locale: selectedLocale
        )
        viewModel.merge(pageViewModels) { old, new in
            Array(Set(old + new))
        }

        let sections = viewModel.map {
            TransactionSectionModel(
                title: viewModelFactory.formatHeader(date: $0.key, locale: selectedLocale),
                date: $0.key,
                items: $0.value.sorted(by: { $0.timestamp > $1.timestamp })
            )
        }.compactMap { $0 }.sorted(by: { $0.date > $1.date })

        view.didReceive(viewModel: sections)
    }

    private func reloadView() {
        guard let view = view else {
            return
        }
        let sections = viewModel.map {
            TransactionSectionModel(
                title: viewModelFactory.formatHeader(date: $0.key, locale: selectedLocale),
                date: $0.key,
                items: $0.value.sorted(by: { $0.timestamp > $1.timestamp })
            )
        }.compactMap { $0 }.sorted(by: { $0.date > $1.date })

        view.didReceive(viewModel: sections)
    }
}

extension TransactionHistoryPresenter: TransactionHistoryPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func select(item: TransactionItemViewModel) {
        guard let view = view, let operation = items[item.identifier] else {
            return
        }

        wireframe.showOperationDetails(
            from: view,
            operation: operation
        )
    }

    func loadNext() {
        guard let view = view, !state.isLoading else {
            return
        }
        view.startLoading()
        interactor.loadNext()
    }

    func showFilter() {
        guard let view = view else {
            return
        }
        wireframe.showFilter(
            from: view,
            filter: filter,
            delegate: self
        )
    }
}

extension TransactionHistoryPresenter: TransactionHistoryInteractorOutputProtocol {
    func didReceive(error: TransactionHistoryError) {
        switch error {
        case let .dataProvider(error):
            if state == .waitingCache {
                state = .cacheLoaded
            }
            logger?.error("Data provider error: \(error.localizedDescription)")
        case let .fetchProvider(error):
            if state == .loadingData {
                state = .dataLoaded
            }
            logger?.error("Error occur \(error.localizedDescription) while fetching data")
        case let .filter(error):
            if state == .filteringData {
                state = .dataFiltered
            }
            logger?.error("Error occur \(error.localizedDescription) while fetching data")
        }
    }

    func didReceive(changes: [DataProviderChange<TransactionHistoryItem>]) {
        if state == .waitingCache {
            state = .cacheLoaded
        }
        items = changes.mergeToDict(items)
        reloadView(items: items)
    }

    func didReceive(nextItems: [TransactionHistoryItem]) {
        if state == .loadingData {
            state = .dataLoaded
        }
        guard let accountAddress = accountAddress, !nextItems.isEmpty else {
            return
        }
        let pageViewModels = viewModelFactory.createGroupModel(
            nextItems,
            address: accountAddress,
            locale: selectedLocale
        )

        items = nextItems.reduceToDict(items)
        viewModel.merge(pageViewModels) { old, new in
            Array(Set(old + new))
        }
        reloadView()
    }

    func didReceive(accountAddress: AccountAddress) {
        self.accountAddress = accountAddress
    }

    func didReceive(filteredItems: [TransactionHistoryItem]) {
        if state == .filteringData {
            state = .dataFiltered
        }
        items = filteredItems.reduceToDict(items)
        reloadView(items: items)
    }

    func clear() {
        viewModel = [:]
        items = [:]
        reloadView()
    }
}

extension TransactionHistoryPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            reloadView()
        }
    }
}

extension TransactionHistoryPresenter: TransactionHistoryFilterEditingDelegate {
    func historyFilterDidEdit(filter: WalletHistoryFilter) {
        self.filter = filter
        view.map { wireframe.closeTopModal(from: $0) }
        state = .filteringData
        clear()
        interactor.set(filter: filter)
    }
}
