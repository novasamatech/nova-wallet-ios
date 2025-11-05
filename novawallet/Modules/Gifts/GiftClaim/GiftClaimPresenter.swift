import Foundation

final class GiftClaimPresenter {
    weak var view: GiftClaimViewProtocol?
    let wireframe: GiftClaimWireframeProtocol
    let interactor: GiftClaimInteractorInputProtocol

    init(
        interactor: GiftClaimInteractorInputProtocol,
        wireframe: GiftClaimWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension GiftClaimPresenter: GiftClaimPresenterProtocol {
    func setup() {}
}

extension GiftClaimPresenter: GiftClaimInteractorOutputProtocol {}
