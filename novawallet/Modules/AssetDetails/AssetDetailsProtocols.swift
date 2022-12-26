import RobinHood

protocol AssetDetailsViewProtocol: AnyObject, ControllerBackedProtocol, Containable {
    func didReceive(assetModel: AssetDetailsModel)
    func didReceive(totalBalance: BalanceViewModelProtocol)
    func didReceive(transferableBalance: BalanceViewModelProtocol)
    func didReceive(lockedBalance: BalanceViewModelProtocol, isSelectable: Bool)
    func didReceive(availableOperations: AssetDetailsOperation)
}

protocol AssetDetailsPresenterProtocol: AnyObject {
    func setup()
    func handleSend()
    func handleReceive()
    func handleBuy()
    func handleLocks()
}

protocol AssetDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AssetDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(balance: AssetBalance?)
    func didReceive(lockChanges: [DataProviderChange<AssetLock>])
    func didReceive(crowdloanChanges: [DataProviderChange<CrowdloanContributionData>])
    func didReceive(price: PriceData?)
    func didReceive(error: AssetDetailsError)
    func didReceive(availableOperations: AssetDetailsOperation)
    func didReceive(purchaseActions: [PurchaseAction])
}

protocol AssetDetailsWireframeProtocol: AnyObject {
    func showSendTokens(from view: AssetDetailsViewProtocol?, chainAsset: ChainAsset)
    func showReceiveTokens(
        from view: AssetDetailsViewProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    )
    func showPurchaseProviders(
        from view: AssetDetailsViewProtocol?,
        actions: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate
    )
    func showPurchaseTokens(
        from view: AssetDetailsViewProtocol?,
        action: PurchaseAction,
        delegate: PurchaseDelegate
    )
    func showNoSigning(from view: AssetDetailsViewProtocol?)
    func showLedgerNotSupport(for tokenName: String, from view: AssetDetailsViewProtocol?)
    func presentSuccessAlert(from view: AssetDetailsViewProtocol?, message: String)
    func showLocks(from view: AssetDetailsViewProtocol?, model: AssetDetailsLocksViewModel)
}

enum AssetDetailsError: Error {
    case accountBalance(Error)
    case price(Error)
    case locks(Error)
    case crowdloans(Error)
}
