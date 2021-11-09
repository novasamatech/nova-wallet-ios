import Foundation

final class CrowdloanListWireframe: CrowdloanListWireframeProtocol {
    let state: CrowdloanSharedState

    private var moonbeamCoordinator: Coordinator?

    init(state: CrowdloanSharedState) {
        self.state = state
    }

    func presentContributionSetup(
        from view: CrowdloanListViewProtocol?,
        crowdloan: Crowdloan,
        displayInfo: CrowdloanDisplayInfo?
    ) {
        if
            let info = displayInfo,
            let flowString = info.customFlow,
            let flow = CrowdloanFlow(rawValue: flowString) {
            switch flow {
            case .moonbeam:
                moonbeamCoordinator = MoonbeamFlowCoordinatorFactory.createCoordinator(
                    previousView: view,
                    state: state,
                    crowdloan: crowdloan,
                    displayInfo: info
                )
                moonbeamCoordinator?.start()
            case .acala:
                showAcalaContributionSetup(from: view, paraId: crowdloan.paraId)
            default:
                showContributionSetup(from: view, paraId: crowdloan.paraId)
            }
        } else {
            showContributionSetup(from: view, paraId: crowdloan.paraId)
        }
    }

    func showYourContributions(
        crowdloans: [Crowdloan],
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        from view: ControllerBackedProtocol?
    ) {
        let input = CrowdloanYourContributionsViewInput(
            crowdloans: crowdloans,
            contributions: viewInfo.contributions,
            displayInfo: viewInfo.displayInfo,
            chainAsset: chainAsset
        )
        guard let contibutions = CrowdloanYourContributionsViewFactory.createView(input: input)
        else { return }

        contibutions.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(contibutions.controller, animated: true)
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

    private func showAcalaContributionSetup(from view: ControllerBackedProtocol?, paraId: ParaId) {
        guard let setupView = AcalaContributionSetupViewFactory.createView(
            for: paraId,
            state: state
        ) else {
            return
        }

        setupView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(setupView.controller, animated: true)
    }

    func selectChain(
        from view: ControllerBackedProtocol?,
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
