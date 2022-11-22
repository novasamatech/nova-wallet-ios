import Foundation

final class ReferendumsWireframe: ReferendumsWireframeProtocol {
    let state: GovernanceSharedState

    init(state: GovernanceSharedState) {
        self.state = state
    }

    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: AssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?
    ) {
        let assetFilter: (ChainAsset) -> Bool = { chainAsset in
            chainAsset.chain.hasGovernance && chainAsset.asset.isUtility
        }

        guard let selectionView = AssetSelectionViewFactory.createView(
            delegate: delegate,
            selectedChainAssetId: selectedChainAssetId,
            balanceSlice: \.freeInPlank,
            assetFilter: assetFilter
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
}
