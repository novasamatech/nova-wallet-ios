import Foundation

final class CrowdloanListWireframe: CrowdloanListWireframeProtocol {
    let state: CrowdloanSharedState

    private var moonbeamCoordinator: Coordinator?

    init(state: CrowdloanSharedState) {
        self.state = state
    }

    func showWalletDetails(from view: ControllerBackedProtocol?, wallet: MetaAccountModel) {
        guard let accountManagementView = AccountManagementViewFactory.createView(for: wallet.identifier) else {
            return
        }

        view?.controller.navigationController?.pushViewController(accountManagementView.controller, animated: true)
    }

    func showYourContributions(
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        from view: ControllerBackedProtocol?
    ) {
        let input = CrowdloanYourContributionsViewInput(
            contributions: viewInfo.contributions,
            displayInfo: viewInfo.displayInfo,
            chainAsset: chainAsset
        )
        guard let contributionsModule = CrowdloanYourContributionsViewFactory
            .createView(input: input, sharedState: state)
        else { return }

        contributionsModule.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(contributionsModule.controller, animated: true)
    }

    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: ChainAssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?
    ) {
        let assetFilter: (ChainAsset) -> Bool = { chainAsset in
            chainAsset.chain.syncMode.enabled()
                && chainAsset.chain.hasCrowdloans
                && chainAsset.asset.isUtility
        }

        guard let selectionView = ChainAssetSelectionViewFactory.createView(
            delegate: delegate,
            selectedChainAssetId: selectedChainAssetId,
            assetFilter: assetFilter
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }
}
