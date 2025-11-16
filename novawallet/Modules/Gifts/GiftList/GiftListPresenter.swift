import Foundation

final class GiftListPresenter {
    weak var view: GiftListViewProtocol?
    let wireframe: GiftListWireframeProtocol
    let interactor: GiftListInteractorInputProtocol

    init(
        interactor: GiftListInteractorInputProtocol,
        wireframe: GiftListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension GiftListPresenter: GiftListPresenterProtocol {
    func setup() {}
}

extension GiftListPresenter: GiftListInteractorOutputProtocol {}