import Foundation

final class MoonbeamTermsPresenter {
    weak var view: MoonbeamTermsViewProtocol?
    let wireframe: MoonbeamTermsWireframeProtocol
    let interactor: MoonbeamTermsInteractorInputProtocol

    init(
        interactor: MoonbeamTermsInteractorInputProtocol,
        wireframe: MoonbeamTermsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension MoonbeamTermsPresenter: MoonbeamTermsPresenterProtocol {
    func setup() {}
}

extension MoonbeamTermsPresenter: MoonbeamTermsInteractorOutputProtocol {}
