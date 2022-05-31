import Foundation

final class ParaStkYourCollatorsPresenter {
    weak var view: ParaStkYourCollatorsViewProtocol?
    let wireframe: ParaStkYourCollatorsWireframeProtocol
    let interactor: ParaStkYourCollatorsInteractorInputProtocol

    init(
        interactor: ParaStkYourCollatorsInteractorInputProtocol,
        wireframe: ParaStkYourCollatorsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ParaStkYourCollatorsPresenter: ParaStkYourCollatorsPresenterProtocol {
    func setup() {}

    func retry() {}

    func manageCollators() {}

    func selectCollator(viewModel _: CollatorSelectionViewModel) {}
}

extension ParaStkYourCollatorsPresenter: ParaStkYourCollatorsInteractorOutputProtocol {}
