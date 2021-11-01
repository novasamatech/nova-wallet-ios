import Foundation

struct CrowdloanYourContributionsViewFactory {
    static func createView(contributions _: [CrowdloanContributionItem]) -> CrowdloanYourContributionsViewProtocol? {
        let interactor = CrowdloanYourContributionsInteractor()
        let wireframe = CrowdloanYourContributionsWireframe()

        let presenter = CrowdloanYourContributionsPresenter(interactor: interactor, wireframe: wireframe)

        let view = CrowdloanYourContributionsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
