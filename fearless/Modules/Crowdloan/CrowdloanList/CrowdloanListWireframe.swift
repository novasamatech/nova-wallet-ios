import Foundation

final class CrowdloanListWireframe: CrowdloanListWireframeProtocol {
    let state: CrowdloanSharedState

    private var moonbeamCoordinator: Coordinator?

    init(state: CrowdloanSharedState) {
        self.state = state
    }

    func presentContributionSetup(
        from view: CrowdloanListViewProtocol?,
        paraId: ParaId,
        displayInfo: CrowdloanDisplayInfo?,
        contrubution: CrowdloanContribution?
    ) {
        if let info = displayInfo, info.customFlow == .moonbeam {
            moonbeamCoordinator = MoonbeamFlowCoordinatorFactory.createCoordinator(
                previousView: view,
                state: state,
                paraId: paraId,
                displayInfo: info,
                contrubution: contrubution
            )
            moonbeamCoordinator?.start()
        } else {
            showContributionSetup(from: view, paraId: paraId)
        }
    }

    private func showContributionSetup(from view: CrowdloanListViewProtocol?, paraId: ParaId) {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(
            for: paraId,
            state: state
        ) else {
            return
        }

        setupView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(setupView.controller, animated: true)
    }

    func selectChain(
        from view: CrowdloanListViewProtocol?,
        delegate: ChainSelectionDelegate,
        selectedChainId: ChainModel.Id?
    ) {
        guard let selectionView = ChainSelectionViewFactory.createView(
            delegate: delegate,
            selectedChainId: selectedChainId,
            repositoryFilter: NSPredicate.hasCrowloans()
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
