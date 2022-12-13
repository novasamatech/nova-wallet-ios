protocol TransactionHistoryViewProtocol: AnyObject {
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
    func loadNext()
}

protocol TransactionHistoryInteractorOutputProtocol: AnyObject {
    
}

protocol TransactionHistoryWireframeProtocol: AnyObject {
    
}
