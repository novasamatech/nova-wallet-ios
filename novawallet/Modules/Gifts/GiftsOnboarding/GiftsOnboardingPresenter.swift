import Foundation

final class GiftsOnboardingPresenter {
    weak var view: GiftsOnboardingViewProtocol?
    let wireframe: GiftsOnboardingWireframeProtocol
    let interactor: GiftsOnboardingInteractorInputProtocol

    init(
        interactor: GiftsOnboardingInteractorInputProtocol,
        wireframe: GiftsOnboardingWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension GiftsOnboardingPresenter: GiftsOnboardingPresenterProtocol {
    func setup() {}
}

extension GiftsOnboardingPresenter: GiftsOnboardingInteractorOutputProtocol {}