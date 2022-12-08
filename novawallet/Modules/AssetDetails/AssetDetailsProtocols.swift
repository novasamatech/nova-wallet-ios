protocol AssetDetailsViewProtocol: AnyObject, ControllerBackedProtocol {
    func didReceive(assetModel: AssetDetailsModel)
    func didReceive(totalBalance: BalanceViewModelProtocol)
    func didReceive(transferableBalance: BalanceViewModelProtocol)
    func didReceive(lockedBalance: BalanceViewModelProtocol, isSelectable: Bool)
    func didReceive(availableOperations: Operations)
}

protocol AssetDetailsPresenterProtocol: AnyObject {
    func setup()
    func didTapSendButton()
    func didTapReceiveButton()
    func didTapBuyButton()
    func didTapLocks()
}

protocol AssetDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AssetDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(balance: AssetBalance?)
    func didReceive(locks: [AssetLock])
    func didReceive(crowdloans: [CrowdloanContributionData])
    func didReceive(price: PriceData?)
    func didReceive(error: AssetDetailsError)
    func didReceive(availableOperations: Operations)
    func didReceive(purchaseActions: [PurchaseAction])
}

protocol AssetDetailsWireframeProtocol: AnyObject {
    func showSendTokens(from view: AssetDetailsViewProtocol?, chainAsset: ChainAsset)
    func showReceiveTokens(from view: AssetDetailsViewProtocol?)
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
