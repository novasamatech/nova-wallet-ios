import Foundation

final class GiftHistoryCheckPresenter {
    weak var view: GiftHistoryCheckViewProtocol?
    let wireframe: GiftHistoryCheckWireframeProtocol
    let interactor: GiftHistoryCheckInteractorInputProtocol

    init(
        interactor: GiftHistoryCheckInteractorInputProtocol,
        wireframe: GiftHistoryCheckWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension GiftHistoryCheckPresenter: GiftHistoryCheckPresenterProtocol {
    func setup() {}
}

extension GiftHistoryCheckPresenter: GiftHistoryCheckInteractorOutputProtocol {}