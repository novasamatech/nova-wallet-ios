import CommonWallet
import RobinHood

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
    func setup(historyFilter: WalletHistoryFilter)
    func refresh()
    func loadNext()
}

protocol TransactionHistoryInteractorOutputProtocol: AnyObject {
    func didReceive(error: Error)
    func didReceive(changes: [DataProviderChange<TransactionHistoryItem>])
}

protocol TransactionHistoryWireframeProtocol: AnyObject {}
