import BigInt
import CommonWallet

protocol NftDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(name: String?)
    func didReceive(label: String?)
    func didReceive(description: String?)
    func didReceive(media: NftMediaViewModelProtocol?)
    func didReceive(price: BalanceViewModelProtocol?)
    func didReceive(collectionViewModel: StackCellViewModel?)
    func didReceive(ownerViewModel: DisplayAddressViewModel)
    func didReceive(issuerViewModel: DisplayAddressViewModel?)
    func didReceive(networkViewModel: NetworkViewModel)
}

protocol NftDetailsPresenterProtocol: AnyObject {
    func setup()
    func selectOwner()
    func selectIssuer()
}

protocol NftDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol NftDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(name: String?)
    func didReceive(label: NftDetailsLabel?)
    func didReceive(description: String?)
    func didReceive(media: NftMediaViewModelProtocol?)
    func didReceive(price: BigUInt?, tokenPriceData: PriceData?)
    func didReceive(collection: NftDetailsCollection?)
    func didReceive(owner: DisplayAddress)
    func didReceive(issuer: DisplayAddress?)
    func didReceive(error: Error)
}

protocol NftDetailsWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable {}
