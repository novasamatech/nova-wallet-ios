import CommonWallet
import RobinHood

protocol TransactionHistoryViewProtocol: ControllerBackedProtocol, Draggable {
    func startLoading()
    func stopLoading()
    func didReceive(viewModel: [TransactionSectionModel])
}

protocol TransactionHistoryPresenterProtocol: AnyObject {
    func setup()
    func select(item: TransactionItemViewModel)
    func loadNext()
    func showFilter()
}

protocol TransactionHistoryInteractorInputProtocol: AnyObject {
    func setup()
    func set(filter: WalletHistoryFilter)
    func loadNext()
}

protocol TransactionHistoryInteractorOutputProtocol: AnyObject {
    func didReceive(error: TransactionHistoryError)
    func didReceive(changes: [DataProviderChange<TransactionHistoryItem>])
    func didReceive(priceCalculator: TokenPriceCalculatorProtocol)
    func didReceiveFetchingState(isComplete: Bool)
}

protocol TransactionHistoryWireframeProtocol: AnyObject {
    func showFilter(
        from view: TransactionHistoryViewProtocol,
        filter: WalletHistoryFilter,
        delegate: TransactionHistoryFilterEditingDelegate?
    )
    func showOperationDetails(
        from view: TransactionHistoryViewProtocol,
        operation: TransactionHistoryItem
    )
    func closeTopModal(from view: TransactionHistoryViewProtocol)
}

enum TransactionHistoryError: Error {
    case fetchFailed(Error)
    case setupFailed(Error)
    case priceFailed(Error)
}
