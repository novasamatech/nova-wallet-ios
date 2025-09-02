import Foundation
import Foundation_iOS

struct GovEditDelegationTracksViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        delegate: GovernanceDelegateFlowDisplayInfo<AccountId>
    ) -> GovernanceSelectTracksViewProtocol? {
        guard
            let interactor = GovernanceSelectTracksViewFactory.createInteractor(for: state),
            let chain = state.settings.value?.chain else {
            return nil
        }

        let wireframe = GovEditDelegationTracksWireframe(
            state: state,
            delegateDisplayInfo: delegate
        )

        let localizationManager = LocalizationManager.shared

        let presenter = GovEditDelegationTracksPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegateId: delegate.additions,
            chain: chain,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = GovEditDelegationTracksViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.basePresenter = presenter

        return view
    }
}
