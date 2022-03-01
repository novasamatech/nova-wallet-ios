import Foundation

final class NftListPresenter {
    weak var view: NftListViewProtocol?
    let wireframe: NftListWireframeProtocol
    let interactor: NftListInteractorInputProtocol

    init(
        interactor: NftListInteractorInputProtocol,
        wireframe: NftListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NftListPresenter: NftListPresenterProtocol {
    func setup() {}
}

extension NftListPresenter: NftListInteractorOutputProtocol {}
