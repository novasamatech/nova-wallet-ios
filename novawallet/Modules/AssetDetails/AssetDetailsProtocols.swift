import Operation_iOS

protocol AssetDetailsViewProtocol: AnyObject, ControllerBackedProtocol, Containable {
    func didReceive(assetModel: AssetDetailsModel)
    func didReceive(balance: AssetDetailsBalanceModel)
    func didReceive(availableOperations: AssetDetailsOperation)
    func didReceiveChartAvailable(_ available: Bool)
}

protocol AssetDetailsPresenterProtocol: AnyObject {
    func setup()
    func handleSend()
    func handleReceive()
    func handleBuySell()
    func handleLocks()
    func handleSwap()
}

protocol AssetDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AssetDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(balance: AssetBalance?)
    func didReceive(lockChanges: [DataProviderChange<AssetLock>])
    func didReceive(holdsChanges: [DataProviderChange<AssetHold>])
    func didReceive(externalBalanceChanges: [DataProviderChange<ExternalAssetBalance>])
    func didReceive(price: PriceData?)
    func didReceive(error: AssetDetailsError)
    func didReceive(availableOperations: AssetDetailsOperation)
    func didReceive(rampActions: [RampAction])
}

protocol AssetDetailsWireframeProtocol: AnyObject,
    RampActionsPresentable, RampPresentable, AlertPresentable,
    MessageSheetPresentable, FeatureSupportChecking {
    func showSendTokens(from view: AssetDetailsViewProtocol?, chainAsset: ChainAsset)
    func showReceiveTokens(
        from view: AssetDetailsViewProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    )
    func showNoSigning(from view: AssetDetailsViewProtocol?)
    func showLedgerNotSupport(for tokenName: String, from view: AssetDetailsViewProtocol?)
    func showLocks(from view: AssetDetailsViewProtocol?, model: AssetDetailsLocksViewModel)
    func showSwaps(from view: AssetDetailsViewProtocol?, chainAsset: ChainAsset)
    func dropModalFlow(
        from view: AssetDetailsViewProtocol?,
        completion: @escaping () -> Void
    )
}

enum AssetDetailsError: Error {
    case accountBalance(Error)
    case price(Error)
    case locks(Error)
    case externalBalances(Error)
    case swaps(Error)
    case holds(Error)
}
