import Foundation
import SoraFoundation

struct GovernanceAddDelegationTracksViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        delegate: AccountId
    ) -> GovernanceSelectTracksViewProtocol? {
        guard
            let interactor = GovernanceSelectTracksViewFactory.createInteractor(for: state),
            let chain = state.settings.value?.chain else {
            return nil
        }

        let wireframe = GovernanceAddDelegationTracksWireframe(
            state: state,
            delegate: delegate
        )

        let presenter = GovernanceAddDelegationTracksPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = GovAddDelegationTracksViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
