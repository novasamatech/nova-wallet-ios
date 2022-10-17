import Foundation

struct ReferendumFullDetailsViewFactory {
    static func createView(
        state: GovernanceSharedState,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        identities: [AccountAddress: AccountIdentity]
    ) -> ReferendumFullDetailsViewProtocol? {
        guard let chain = state.settings.value else {
            return nil
        }

        let wireframe = ReferendumFullDetailsWireframe()

        let presenter = ReferendumFullDetailsPresenter(
            wireframe: wireframe,
            chain: chain,
            referendum: referendum,
            actionDetails: actionDetails,
            identities: identities
        )

        let view = ReferendumFullDetailsViewController(presenter: presenter)

        presenter.view = view

        return view
    }
}
