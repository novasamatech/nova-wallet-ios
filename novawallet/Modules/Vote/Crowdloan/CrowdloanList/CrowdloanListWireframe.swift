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

    func presentContributionSetup(
        from view: (ControllerBackedProtocol & AlertPresentable & LoadableViewProtocol)?,
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
        guard let contributionsModule = CrowdloanYourContributionsViewFactory
            .createView(input: input, sharedState: state)
        else { return }

        contributionsModule.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(contributionsModule.controller, animated: true)
    }

    private func showContributionSetup(from view: ControllerBackedProtocol?, paraId: ParaId) {
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
        delegate: AssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?
    ) {
        let assetFilter: (ChainAsset) -> Bool = { chainAsset in
            chainAsset.chain.hasCrowdloans && chainAsset.asset.isUtility
        }

        guard let selectionView = AssetSelectionViewFactory.createView(
            delegate: delegate,
            selectedChainAssetId: selectedChainAssetId,
            assetFilter: assetFilter
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
