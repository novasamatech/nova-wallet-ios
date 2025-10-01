import Foundation
import Foundation_iOS

import Operation_iOS

final class TransactionHistoryPresenter {
    weak var view: TransactionHistoryViewProtocol?
    let wireframe: TransactionHistoryWireframeProtocol
    let interactor: TransactionHistoryInteractorInputProtocol
    let viewModelFactory: TransactionHistoryViewModelFactoryProtocol
    let logger: LoggerProtocol?
    let address: AccountAddress

    private var ahmFullInfo: AHMFullInfo?
    private var items: [String: TransactionHistoryItem] = [:]
    private var filter: WalletHistoryFilter = .all
    private var priceCalculator: TokenPriceCalculatorProtocol?
    private var localFilter: TransactionHistoryLocalFilterProtocol?

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

        guard let localFilter = localFilter else {
            view.didReceive(viewModel: [])
            return
        }

        let models = Array(items.values).filter { localFilter.shouldDisplayOperation(model: $0) }

        let sections = viewModelFactory.createGroupModel(
            models,
            priceCalculator: priceCalculator,
            address: address,
            ahmInfo: ahmFullInfo,
            locale: selectedLocale
        )

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
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .localFilter:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryLocalFilter()
            }
        }
    }

    func didReceive(changes: [DataProviderChange<TransactionHistoryItem>]) {
        if !changes.isEmpty {
            items = changes.mergeToDict(items)
            reloadView()
        }
    }

    func didReceive(priceCalculator: TokenPriceCalculatorProtocol) {
        self.priceCalculator = priceCalculator

        reloadView()
    }

    func didReceive(localFilter: TransactionHistoryLocalFilterProtocol) {
        self.localFilter = localFilter

        reloadView()
    }

    func didReceiveFetchingState(isComplete: Bool) {
        if isComplete {
            view?.stopLoading()
        } else {
            view?.startLoading()
        }
    }

    func didReceive(ahmFullInfo: AHMFullInfo) {
        guard self.ahmFullInfo != ahmFullInfo else { return }

        self.ahmFullInfo = ahmFullInfo

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
