import Foundation

final class PayShopPresenter {
    weak var view: PayShopViewProtocol?
    let wireframe: PayShopWireframeProtocol
    let interactor: PayShopInteractorInputProtocol

    init(
        interactor: PayShopInteractorInputProtocol,
        wireframe: PayShopWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension PayShopPresenter: PayShopPresenterProtocol {
    func setup() {}
}

extension PayShopPresenter: PayShopInteractorOutputProtocol {}
