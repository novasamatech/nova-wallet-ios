import Foundation

struct StackingRewardFiltersViewFactory {
    static func createView() -> StackingRewardFiltersViewProtocol? {
        let interactor = StackingRewardFiltersInteractor()
        let wireframe = StackingRewardFiltersWireframe()

        let presenter = StackingRewardFiltersPresenter(interactor: interactor, wireframe: wireframe)

        let view = StackingRewardFiltersViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
