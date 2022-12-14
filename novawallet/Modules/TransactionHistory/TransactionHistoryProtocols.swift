import CommonWallet

protocol TransactionHistoryViewProtocol: ControllerBackedProtocol {
    func startLoading()
    func stopLoading()
    func didReceive(viewModel: [TransactionSectionModel])
}

protocol TransactionHistoryPresenterProtocol: AnyObject {
    func setup()
    func viewDidAppear()
    func select(item: TransactionItemViewModel)
    func loadNext()
}

protocol TransactionHistoryInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func loadNext(
        for filter: WalletHistoryRequest,
        pagination: Pagination
    )
}

protocol TransactionHistoryInteractorOutputProtocol: AnyObject {
    func didReceive(error: Error, for: Pagination)
    func didReceive(transactionData: AssetTransactionPageData, for: Pagination)
}

protocol TransactionHistoryWireframeProtocol: AnyObject {}
