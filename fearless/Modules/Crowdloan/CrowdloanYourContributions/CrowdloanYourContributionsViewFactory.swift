import Foundation

struct CrowdloanYourContributionsViewFactory {
    static func createView() -> CrowdloanYourContributionsViewProtocol? {
        let interactor = CrowdloanYourContributionsInteractor()
        let wireframe = CrowdloanYourContributionsWireframe()

        let presenter = CrowdloanYourContributionsPresenter(interactor: interactor, wireframe: wireframe)

        let view = CrowdloanYourContributionsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
