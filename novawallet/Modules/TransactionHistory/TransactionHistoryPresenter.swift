import Foundation
import SoraFoundation
import CommonWallet

final class TransactionHistoryPresenter {
    weak var view: TransactionHistoryViewProtocol?
    let wireframe: TransactionHistoryWireframeProtocol
    let interactor: TransactionHistoryInteractorInputProtocol
    let viewModelFactory: TransactionHistoryViewModelFactory2Protocol
    
    private let transactionsPerPage: Int
    private let logger: LoggerProtocol?
    
    private var filter: WalletHistoryRequest
    private var dataLoadingState: DataState = .waitingCached
    private var viewModel: [String: [TransactionItemViewModel]] = [:]
    
    init(
        interactor: TransactionHistoryInteractorInputProtocol,
        wireframe: TransactionHistoryWireframeProtocol,
        transactionsPerPage: Int = 100,
        filter: WalletHistoryRequest,
        viewModelFactory: TransactionHistoryViewModelFactory2Protocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.transactionsPerPage = transactionsPerPage
        self.filter = filter
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        
        self.localizationManager = localizationManager
    }
    
    enum DataState {
        case waitingCached
        case loading(page: Pagination, previousPage: Pagination?)
        case loaded(page: Pagination?, nextContext: PaginationContext?)
        case filtering(page: Pagination, previousPage: Pagination?)
        case filtered(page: Pagination?, nextContext: PaginationContext?)
    }
    
    private func reloadView(with pageData: AssetTransactionPageData,
                            andSwitch newDataLoadingState: DataState) throws {
        guard let view = view else {
            return
        }
        let pageViewModels = try viewModelFactory.createGroupModel(pageData.transactions,
                                                                   locale: selectedLocale)
        self.dataLoadingState = newDataLoadingState
        self.viewModel = try viewModel.merge(pageViewModels) { (_, new) in new }
        
        let sections = self.viewModel.map {
            TransactionSectionModel(title: $0.key,
                                    items: $0.value)
        }
        
        view.didReceive(viewModel: sections)
    }

    private func reloadView() throws {
        let sections = viewModel.map {
            TransactionSectionModel(title: $0.key,
                                    items: $0.value)
        }
        
        view.didReceive(viewModel: sections)
    }

    private func resetView(with newState: DataState) {
        dataLoadingState = newState
        viewModels = [:]
        reloadView()
    }

    private func appendPage(with pageData: AssetTransactionPageData,
                            andSwitch newDataLoadingState: DataState) throws {
        self.dataLoadingState = newDataLoadingState
        self.pages.append(pageData)
        reloadView(with: pageData,
                   andSwitch: newDataLoadingState)
    }
    
    private func handleDataProvider(transactionData: AssetTransactionPageData?) {
        switch dataLoadingState {
        case .waitingCached:
            do {
                let loadedTransactionData = transactionData ?? AssetTransactionPageData(transactions: [])
                let newState = DataState.loading(page: Pagination(count: transactionsPerPage), previousPage: nil)
               // dataProvider.refresh()
                try reloadView(with: loadedTransactionData, andSwitch: newState)
            } catch {
                logger?.error("Did receive cache processing error \(error)")
            }
        case .loading, .loaded:
            do {
                if let transactionData = transactionData {
                    let loadedPage = Pagination(count: transactionData.transactions.count)
                    let newState = DataState.loaded(page: loadedPage, nextContext: transactionData.context)
                    try reloadView(with: transactionData, andSwitch: newState)
                } else if let firstPage = pages.first {
                    let loadedPage = Pagination(count: firstPage.transactions.count)
                    let newState = DataState.loaded(page: loadedPage, nextContext: firstPage.context)
                    try reloadView(with: firstPage, andSwitch: newState)
                } else {
                    logger?.error("Inconsistent data loading before cache")
                }
            } catch {
                logger?.debug("Did receive cache update processing error \(error)")
            }
        default: break
        }
    }

    private func handleDataProvider(error: Error) {
        logger?.error("Cache unexpectedly failed \(error)")
        reloadView()
    }

    private func handleNext(transactionData: AssetTransactionPageData, for pagination: Pagination) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Unexpected page loading before cache")
        case .loading(let currentPagination, _):
            if currentPagination == pagination {
                do {
                    let loadedPage = Pagination(count: transactionData.transactions.count, context: pagination.context)
                    let newState = DataState.loaded(page: loadedPage, nextContext: transactionData.context)
                    try appendPage(with: transactionData, andSwitch: newState)
                } catch {
                    logger?.error("Did receive page processing error \(error)")
                }
            } else {
                logger?.debug("Unexpected loaded page with context \(String(describing: pagination.context))")
            }
        case .loaded, .filtered:
            logger?.debug("Context loaded \(String(describing: pagination.context)) loaded but not expected")
        case .filtering(let currentPagination, let prevPagination):
            if currentPagination == pagination {
                do {
                    let loadedPage = Pagination(count: transactionData.transactions.count,
                                                context: pagination.context)
                    let newState = DataState.filtered(page: loadedPage, nextContext: transactionData.context)

                    if prevPagination == nil {
                        try reloadView(with: transactionData, andSwitch: newState)
                    } else {
                        try appendPage(with: transactionData, andSwitch: newState)
                    }
                } catch {
                    logger?.error("Did receive page processing error \(error)")
                }
            } else {
                logger?.debug("Context loaded \(String(describing: pagination.context)) but not expected")
            }
        }
    }

    private func handleNext(error: Error, for pagination: Pagination) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Cached data expected but received page error \(error)")
        case .loading(let currentPage, let previousPage):
            if currentPage == pagination {
                logger?.debug("Loading page with context \(String(describing: pagination.context)) failed")

                dataLoadingState = .loaded(page: previousPage, nextContext: currentPage.context)
            } else {
                logger?.debug("Unexpected pagination context \(String(describing: pagination.context))")
            }
        case .filtering(let currentPage, let previousPage):
            if currentPage == pagination {
                logger?.debug("Loading page with context \(String(describing: pagination.context)) failed")
                
                dataLoadingState = .filtered(page: previousPage, nextContext: currentPage.context)
            } else {
                logger?.debug("Unexpected failed page with context \(String(describing: pagination.context))")
            }
        case .loaded, .filtered:
            logger?.debug("Failed page already loaded")
        }
    }
    
}

extension TransactionHistoryPresenter: TransactionHistoryPresenterProtocol {
    var isLoading: Bool {
        switch dataLoadingState {
        case .filtering, .loading, .waitingCached:
            return true
        case .filtered, .loaded:
            return false
        }
    }

    func setup() {
        interactor.setup()
    }
    
    func viewDidAppear() {
        dataLoadingState = .loading(page: Pagination(count: transactionsPerPage), previousPage: nil)
        interactor.refresh()
    }
    
    func select(item: TransactionItemViewModel) {
        //wireframe
    }
    
    func loadNext() {
        switch dataLoadingState {
        case .waitingCached:
            return false
        case .loading(_, let previousPage):
            return previousPage != nil
        case .loaded(let currentPage, let context):
            if let currentPage = currentPage, context != nil {
                let nextPage = Pagination(count: transactionsPerPage, context: context)
                dataLoadingState = .loading(page: nextPage, previousPage: currentPage)
                loadTransactions(for: nextPage)

                return true
            } else {
                return false
            }
        case .filtering(_, let previousPage):
            return previousPage != nil
        case .filtered(let page, let context):
            if let currentPage = page, context != nil {
                let nextPage = Pagination(count: transactionsPerPage, context: context)
                dataLoadingState = .filtering(page: nextPage, previousPage: currentPage)
                loadTransactions(for: nextPage)
                
                return true
            } else {
                return false
            }
        }
    }

    func showFilter() {
        //wireframe.presentFilter(filter: selectedFilter, assets: assets)
    }
    
}

extension TransactionHistoryPresenter: TransactionHistoryInteractorOutputProtocol {}

extension TransactionHistoryPresenter: Localizable {
    func applyLocalization() {
        if view?.isLoaded == true {
            reloadView()
        }
    }
}
