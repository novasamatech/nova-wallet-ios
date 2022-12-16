import Foundation
import SoraFoundation
import CommonWallet
import RobinHood

final class TransactionHistoryPresenter {
    weak var view: TransactionHistoryViewProtocol?
    let wireframe: TransactionHistoryWireframeProtocol
    let interactor: TransactionHistoryInteractorInputProtocol
    let viewModelFactory: TransactionHistoryViewModelFactory2Protocol
    let chainAsset: ChainAsset

    private let transactionsPerPage: Int
    private let logger: LoggerProtocol?

    private var filter: WalletHistoryRequest
    private var viewModel: [Date: [TransactionItemViewModel]] = [:]
    private var items: [TransactionHistoryItem] = []

    init(
        interactor: TransactionHistoryInteractorInputProtocol,
        wireframe: TransactionHistoryWireframeProtocol,
        transactionsPerPage: Int = 100,
        filter: WalletHistoryRequest,
        viewModelFactory: TransactionHistoryViewModelFactory2Protocol,
        localizationManager: LocalizationManagerProtocol,
        chainAsset: ChainAsset,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.transactionsPerPage = transactionsPerPage
        self.filter = filter
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.chainAsset = chainAsset

        self.localizationManager = localizationManager
    }

    private func reloadView(items: [TransactionHistoryItem]) throws {
        guard let view = view else {
            return
        }
        let pageViewModels = try viewModelFactory.createGroupModel(
            items.map { AssetTransactionData.createTransaction(
                from: $0,
                address: "",
                chainAsset: chainAsset,
                utilityAsset: chainAsset.chain.utilityAsset()!
            ) },
            locale: selectedLocale
        )
        viewModel.merge(pageViewModels) { _, new in new }

        let sections = viewModel.map {
            TransactionSectionModel(
                title: viewModelFactory.formatHeader(date: $0.key, locale: selectedLocale),
                date: $0.key,
                items: $0.value.sorted(by: { $0.timestamp < $1.timestamp })
            )
        }.compactMap { $0 }.sorted(by: { $0.date > $1.date })

        view.didReceive(viewModel: sections)
    }

    private func reloadView() throws {
        guard let view = view else {
            return
        }
        let sections = viewModel.map {
            TransactionSectionModel(
                title: viewModelFactory.formatHeader(date: $0.key, locale: selectedLocale),
                date: $0.key,
                items: $0.value.sorted(by: { $0.timestamp < $1.timestamp })
            )
        }.sorted(by: { $0.date < $1.date })

        view.didReceive(viewModel: sections)
    }

    private func resetView() {
        viewModel = [:]
        try? reloadView()
    }
}

extension TransactionHistoryPresenter: TransactionHistoryPresenterProtocol {
    func setup() {
        interactor.setup(historyFilter: .all)
    }

    func viewDidAppear() {
        interactor.refresh()
    }

    func select(item _: TransactionItemViewModel) {
        // wireframe
    }

    func loadNext() {
        guard let view = view else {
            return
        }
        view.startLoading()
        interactor.loadNext()
    }

    func showFilter() {
        // wireframe.presentFilter(filter: selectedFilter, assets: assets)
    }
}

extension TransactionHistoryPresenter: TransactionHistoryInteractorOutputProtocol {
    func didReceive(error: Error) {
        logger?.error("Cached data expected but received page error \(error)")
    }

    func didReceive(changes: [DataProviderChange<TransactionHistoryItem>]) {
        items = items.applying(changes: changes)
        try? reloadView(items: items)
    }
}

extension TransactionHistoryPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            try? reloadView()
        }
    }
}
