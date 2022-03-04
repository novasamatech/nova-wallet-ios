import Foundation

final class NftDetailsPresenter {
    weak var view: NftDetailsViewProtocol?
    let wireframe: NftDetailsWireframeProtocol
    let interactor: NftDetailsInteractorInputProtocol

    init(
        interactor: NftDetailsInteractorInputProtocol,
        wireframe: NftDetailsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NftDetailsPresenter: NftDetailsPresenterProtocol {
    func setup() {}
}

extension NftDetailsPresenter: NftDetailsInteractorOutputProtocol {
    func didReceiveName(result _: Result<String?, Error>) {}
    func didReceiveLabel(result _: Result<NftDetailsLabel?, Error>) {}
    func didReceiveDescription(result _: Result<String?, Error>) {}
    func didReceiveMedia(result _: Result<NftMediaViewModelProtocol?, Error>) {}
    func didReceiveChainAsset(result _: Result<ChainAsset, Error>) {}
    func didReceivePrice(result _: Result<PriceData?, Error>) {}
    func didReceiveCollection(result _: Result<NftDetailsCollection?, Error>) {}
    func didReceiveOwner(result _: Result<DisplayAddress, Error>) {}
    func didReceiveIssuer(result _: Result<DisplayAddress?, Error>) {}
}
