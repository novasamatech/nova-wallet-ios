protocol WalletSelectionViewProtocol: ControllerBackedProtocol {}

protocol WalletSelectionPresenterProtocol: AnyObject {
    func setup()
}

protocol WalletSelectionInteractorInputProtocol: AnyObject {
    func setup()
}

protocol WalletSelectionInteractorOutputProtocol: AnyObject {
    func didReceiveWallets()
    func didReceiveBalances(_ balances: [AssetBalance])
    func didReceivePrices(_ prices: [ChainAssetId: PriceData])
    func didReceiveError(_ error: Error)
}

protocol WalletSelectionWireframeProtocol: AnyObject {}
