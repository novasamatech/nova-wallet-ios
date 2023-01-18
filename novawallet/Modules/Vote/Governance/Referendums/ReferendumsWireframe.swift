import Foundation

final class ReferendumsWireframe: ReferendumsWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: GovernanceAssetSelectionDelegate,
        chainId: ChainModel.Id?,
        governanceType: GovernanceType?
    ) {
        guard let selectionView = GovernanceAssetSelectionViewFactory.createView(
            for: delegate,
            chainId: chainId,
            governanceType: governanceType
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showReferendumDetails(from view: ControllerBackedProtocol?, initData: ReferendumDetailsInitData) {
        guard
            let detailsView = ReferendumDetailsViewFactory.createView(
                for: state,
                initData: initData
            ) else {
            return
        }

        detailsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(detailsView.controller, animated: true)
    }

    func showUnlocksDetails(from view: ControllerBackedProtocol?, initData: GovernanceUnlockInitData) {
        guard let unlocksView = GovernanceUnlockSetupViewFactory.createView(for: state, initData: initData) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: unlocksView.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func showDelegations(from view: ControllerBackedProtocol?) {
        guard let delegationsView = AddDelegationViewFactory.createView(state: state) else {
            return
        }

        delegationsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(delegationsView.controller, animated: true)
    }
}
