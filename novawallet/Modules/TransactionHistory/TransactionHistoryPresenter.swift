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
    private var pages: [AssetTransactionPageData] = []

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

    private func reloadView(
        with pageData: AssetTransactionPageData,
        andSwitch newDataLoadingState: DataState
    ) throws {
        guard let view = view else {
            return
        }
        let pageViewModels = try viewModelFactory.createGroupModel(
            pageData.transactions,
            locale: selectedLocale
        )
        dataLoadingState = newDataLoadingState
        viewModel.merge(pageViewModels) { _, new in new }

        let sections = viewModel.map {
            TransactionSectionModel(
                title: $0.key,
                items: $0.value
            )
        }

        view.didReceive(viewModel: sections)
    }

    private func reloadView() throws {
        guard let view = view else {
            return
        }
        let sections = viewModel.map {
            TransactionSectionModel(
                title: $0.key,
                items: $0.value
            )
        }

        view.didReceive(viewModel: sections)
    }

    private func resetView(with newState: DataState) {
        dataLoadingState = newState
        viewModel = [:]
        try? reloadView()
    }

    private func appendPage(
        with pageData: AssetTransactionPageData,
        andSwitch newDataLoadingState: DataState
    ) throws {
        dataLoadingState = newDataLoadingState
        pages.append(pageData)
        try reloadView(
            with: pageData,
            andSwitch: newDataLoadingState
        )
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
    }

    private func handleNext(transactionData: AssetTransactionPageData, for pagination: Pagination) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Unexpected page loading before cache")
        case let .loading(currentPagination, _):
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
        case let .filtering(currentPagination, prevPagination):
            if currentPagination == pagination {
                do {
                    let loadedPage = Pagination(
                        count: transactionData.transactions.count,
                        context: pagination.context
                    )
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
        case let .loading(currentPage, previousPage):
            if currentPage == pagination {
                logger?.debug("Loading page with context \(String(describing: pagination.context)) failed")

                dataLoadingState = .loaded(page: previousPage, nextContext: currentPage.context)
            } else {
                logger?.debug("Unexpected pagination context \(String(describing: pagination.context))")
            }
        case let .filtering(currentPage, previousPage):
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

    func select(item _: TransactionItemViewModel) {
        // wireframe
    }

    func loadNext() {
        guard let view = view else {
            return
        }
        switch dataLoadingState {
        case .waitingCached:
            view.stopLoading()
        case let .loading(_, previousPage):
            previousPage != nil ? view.startLoading() : view.stopLoading()
        case let .loaded(currentPage, context):
            if let currentPage = currentPage, context != nil {
                let nextPage = Pagination(count: transactionsPerPage, context: context)
                dataLoadingState = .loading(page: nextPage, previousPage: currentPage)
                interactor.loadNext(
                    for: filter,
                    pagination: nextPage
                )
                view.startLoading()
            } else {
                view.stopLoading()
            }
        case let .filtering(_, previousPage):
            previousPage != nil ? view.startLoading() : view.stopLoading()
        case let .filtered(page, context):
            if let currentPage = page, context != nil {
                let nextPage = Pagination(count: transactionsPerPage, context: context)
                dataLoadingState = .filtering(page: nextPage, previousPage: currentPage)
                interactor.loadNext(
                    for: filter,
                    pagination: nextPage
                )
                view.startLoading()
            } else {
                view.stopLoading()
            }
        }
    }

    func showFilter() {
        // wireframe.presentFilter(filter: selectedFilter, assets: assets)
    }
}

extension TransactionHistoryPresenter: TransactionHistoryInteractorOutputProtocol {
    func didReceive(error: Error, for page: Pagination) {
        handleNext(error: error, for: page)
    }

    func didReceive(transactionData: AssetTransactionPageData, for page: Pagination) {
        handleNext(transactionData: transactionData, for: page)
    }
}

extension TransactionHistoryPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            try? reloadView()
        }
    }
}
