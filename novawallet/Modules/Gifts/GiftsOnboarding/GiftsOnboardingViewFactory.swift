import Foundation

struct GiftsOnboardingViewFactory {
    static func createView() -> GiftsOnboardingViewProtocol? {
        let interactor = GiftsOnboardingInteractor()
        let wireframe = GiftsOnboardingWireframe()

        let presenter = GiftsOnboardingPresenter(interactor: interactor, wireframe: wireframe)

        let view = GiftsOnboardingViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
