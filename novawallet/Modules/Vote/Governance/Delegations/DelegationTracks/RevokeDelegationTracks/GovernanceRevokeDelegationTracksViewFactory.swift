import Foundation
import Foundation_iOS

struct GovRevokeDelegationTracksViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        delegate: GovernanceDelegateFlowDisplayInfo<AccountId>
    ) -> GovernanceSelectTracksViewProtocol? {
        guard
            let interactor = GovernanceSelectTracksViewFactory.createInteractor(for: state),
            let chain = state.settings.value?.chain else {
            return nil
        }

        let wireframe = GovRevokeDelegationTracksWireframe(
            state: state,
            delegateDisplayInfo: delegate
        )

        let localizationManager = LocalizationManager.shared

        let presenter = GovRevokeDelegationTracksPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegateId: delegate.additions,
            chain: chain,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = GovRevokeDelegationTracksViewController(
            basePresenter: presenter,
            localizationManager: localizationManager
        )

        presenter.baseView = view
        interactor.basePresenter = presenter

        return view
    }
}
