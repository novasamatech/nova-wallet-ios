protocol AssetDetailsViewProtocol: AnyObject, ControllerBackedProtocol {
    func didReceive(totalBalance: BalanceViewModelProtocol)
    func didReceive(transferableBalance: BalanceViewModelProtocol)
    func didReceive(lockedBalance: BalanceViewModelProtocol, isSelectable: Bool)
    func didReceive(availableOperations: Operations)
}

protocol AssetDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol AssetDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AssetDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(balance: AssetBalance?)
    func didReceive(locks: [AssetLock])
    func didReceive(price: PriceData?)
    func didReceive(error: AssetDetailsError)
}

protocol AssetDetailsWireframeProtocol: AnyObject {}

enum AssetDetailsError: Error {
    case accountBalance(Error)
    case price(Error)
    case locks(Error)
}
