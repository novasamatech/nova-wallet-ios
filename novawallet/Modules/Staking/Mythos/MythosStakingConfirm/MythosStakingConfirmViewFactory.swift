import Foundation
import SoraFoundation

struct MythosStakingConfirmViewFactory {
    static func createView(
        for _: MythosStakingSharedStateProtocol,
        model _: MythosStakeModel,
        initialDelegator: MythosStakingDetails?
    ) -> CollatorStakingConfirmViewProtocol? {
        let interactor = MythosStakingConfirmInteractor()
        let wireframe = MythosStakingConfirmWireframe()

        let presenter = MythosStakingConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let screenTitle = CollatorStakingStakeScreenTitle.confirm(hasStake: initialDelegator != nil)

        let view = CollatorStakingConfirmViewController(
            presenter: presenter,
            localizableTitle: screenTitle(),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
