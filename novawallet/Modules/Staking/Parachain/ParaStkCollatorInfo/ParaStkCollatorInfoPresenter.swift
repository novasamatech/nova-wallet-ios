import Foundation

final class ParaStkCollatorInfoPresenter {
    weak var view: ParaStkCollatorInfoViewProtocol?
    let wireframe: ParaStkCollatorInfoWireframeProtocol
    let interactor: ParaStkCollatorInfoInteractorInputProtocol

    private var price: PriceData?

    init(
        interactor: ParaStkCollatorInfoInteractorInputProtocol,
        wireframe: ParaStkCollatorInfoWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ParaStkCollatorInfoPresenter: ParaStkCollatorInfoPresenterProtocol {
    func setup() {}
}

extension ParaStkCollatorInfoPresenter: ParaStkCollatorInfoInteractorOutputProtocol {
    func didReceivePrice(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(price):
            self.price = price
        case let .failure(error):
            break
        }
    }
}
