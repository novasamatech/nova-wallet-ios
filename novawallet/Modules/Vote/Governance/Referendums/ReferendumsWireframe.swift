import Foundation

final class ReferendumsWireframe: ReferendumsWireframeProtocol {
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

    func showReferendumDetails(
        from view: ControllerBackedProtocol?,
        referendum: ReferendumLocal,
        state: GovernanceSharedState
    ) {
        guard let referendumDetails = ReferendumDetailsViewFactory.createView(
            for: referendum,
            state: state
        ) else {
            return
        }
        let navigationController = FearlessNavigationController(
            rootViewController: referendumDetails.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
