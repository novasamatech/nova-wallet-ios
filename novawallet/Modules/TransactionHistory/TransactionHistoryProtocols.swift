import Operation_iOS

protocol TransactionHistoryViewProtocol: ControllerBackedProtocol, Draggable {
    func startLoading()
    func stopLoading()
    func didReceive(viewModel: [TransactionHistorySectionModel])
}

protocol TransactionHistoryPresenterProtocol: AnyObject {
    func setup()
    func select(item: TransactionItemViewModel)
    func loadNext()
    func showFilter()
    func actionViewRelay()
}

protocol TransactionHistoryInteractorInputProtocol: AnyObject {
    func setup()
    func set(filter: WalletHistoryFilter)
    func retryLocalFilter()
    func remakeSubscriptions()
    func loadNext()
}

protocol TransactionHistoryInteractorOutputProtocol: AnyObject {
    func didReceive(ahmFullInfo: AHMFullInfo)
    func didReceive(error: TransactionHistoryError)
    func didReceive(changes: [DataProviderChange<TransactionHistoryItem>])
    func didReceive(priceCalculator: TokenPriceCalculatorProtocol)
    func didReceive(localFilter: TransactionHistoryLocalFilterProtocol)
    func didReceiveFetchingState(isComplete: Bool)
}

protocol TransactionHistoryWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable {
    func showFilter(
        from view: TransactionHistoryViewProtocol,
        filter: WalletHistoryFilter,
        delegate: TransactionHistoryFilterEditingDelegate?
    )
    func showOperationDetails(
        from view: TransactionHistoryViewProtocol,
        operation: TransactionHistoryItem
    )
    func showAssetDetails(
        from view: TransactionHistoryViewProtocol?,
        chainAsset: ChainAsset
    )
    func closeTopModal(from view: TransactionHistoryViewProtocol)
}

enum TransactionHistoryError: Error {
    case fetchFailed(Error)
    case setupFailed(Error)
    case priceFailed(Error)
    case localFilter(Error)
}
