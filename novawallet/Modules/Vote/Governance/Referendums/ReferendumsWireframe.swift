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
            assetFilter: assetFilter
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showReferendumDetails(from view: ControllerBackedProtocol?, referendum: ReferendumLocal) {
        guard let detailsView = ReferendumDetailsViewFactory.createView(for: referendum, state: state) else {
            return
        }

        detailsView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(detailsView.controller, animated: true)
    }
}
