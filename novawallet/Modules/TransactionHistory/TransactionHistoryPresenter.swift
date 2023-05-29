import Foundation
import SoraFoundation
import CommonWallet
import RobinHood

final class TransactionHistoryPresenter {
    weak var view: TransactionHistoryViewProtocol?
    let wireframe: TransactionHistoryWireframeProtocol
    let interactor: TransactionHistoryInteractorInputProtocol
    let viewModelFactory: TransactionHistoryViewModelFactoryProtocol
    let logger: LoggerProtocol?
    let address: AccountAddress

    private var items: [String: TransactionHistoryItem] = [:]
    private var filter: WalletHistoryFilter = .all
    private var priceCalculator: TokenPriceCalculatorProtocol?

    init(
        address: AccountAddress,
        interactor: TransactionHistoryInteractorInputProtocol,
        wireframe: TransactionHistoryWireframeProtocol,
        viewModelFactory: TransactionHistoryViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.address = address
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func reloadView() {
        guard let view = view else {
            return
        }

        let viewModel = viewModelFactory.createGroupModel(
            Array(items.values),
            priceCalculator: priceCalculator,
            address: address,
            locale: selectedLocale
        )

        let sections = viewModel.map {
            TransactionSectionModel(
                title: viewModelFactory.formatHeader(date: $0.key, locale: selectedLocale),
                date: $0.key,
                items: $0.value.sorted(by: { $0.timestamp > $1.timestamp })
            )
        }.compactMap { $0 }.sorted(by: { $0.date > $1.date })

        view.didReceive(viewModel: sections)
    }

    private func clear() {
        items = [:]
        reloadView()
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
        view?.startLoading()
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
        logger?.error("Transaction history error: \(error)")

        switch error {
        case .fetchFailed:
            view?.stopLoading()
        case .setupFailed:
            break
        case .priceFailed:
            break
        }
    }

    func didReceive(changes: [DataProviderChange<TransactionHistoryItem>]) {
        view?.stopLoading()

        if !changes.isEmpty {
            items = changes.mergeToDict(items)
            reloadView()
        }
    }

    func didReceive(priceCalculator: TokenPriceCalculatorProtocol) {
        self.priceCalculator = priceCalculator

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
        clear()
        interactor.set(filter: filter)
    }
}
