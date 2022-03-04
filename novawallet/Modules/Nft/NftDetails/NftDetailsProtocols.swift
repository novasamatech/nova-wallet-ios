import BigInt

protocol NftDetailsViewProtocol: ControllerBackedProtocol {}

protocol NftDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol NftDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol NftDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveName(result: Result<String?, Error>)
    func didReceiveLabel(result: Result<NftDetailsLabel?, Error>)
    func didReceiveDescription(result: Result<String?, Error>)
    func didReceiveMedia(result: Result<NftMediaViewModelProtocol?, Error>)
    func didReceiveChainAsset(result: Result<ChainAsset, Error>)
    func didReceivePrice(result: Result<PriceData?, Error>)
    func didReceiveCollection(result: Result<NftDetailsCollection?, Error>)
    func didReceiveOwner(result: Result<DisplayAddress, Error>)
    func didReceiveIssuer(result: Result<DisplayAddress?, Error>)
}

protocol NftDetailsWireframeProtocol: AnyObject {}
