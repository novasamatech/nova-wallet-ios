import Foundation_iOS

enum SubtensorWhereToStakeViewFactory {
    static func createView(for state: SubtensorStakingSharedStateProtocol) -> SubtensorWhereToStakeViewProtocol {
        let localizationManager = LocalizationManager.shared
        let presenter = SubtensorWhereToStakePresenter(
            interactor: SubtensorWhereToStakeInteractor(),
            wireframe: SubtensorWhereToStakeWireframe(state: state),
            viewModelFactory: SubtensorWhereToStakeViewModelFactory(),
            localizationManager: localizationManager
        )
        let view = SubtensorWhereToStakeViewController(presenter: presenter, localizationManager: localizationManager)
        presenter.view = view
        return view
    }
}
