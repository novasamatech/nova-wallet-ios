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
    func didReceiveName(result: Result<String, Error>) {}
    func didReceiveLabel(result: Result<NftDetailsLabel, Error>) {}
    func didReceiveDescription(result: Result<String, Error>) {}
    func didReceiveMedia(result: Result<NftMediaViewModelProtocol, Error>) {}
    func didReceiveChain(result: Result<ChainModel, Error>) {}
    func didReceivePrice(result: Result<PriceData?, Error>) {}
    func didReceiveCollection(result: Result<NftDetailsCollection?, Error>) {}
    func didReceiveOwner(result: Result<DisplayAddress, Error>) {}
    func didReceiveIssuer(result: Result<DisplayAddress?, Error>) {}
}
