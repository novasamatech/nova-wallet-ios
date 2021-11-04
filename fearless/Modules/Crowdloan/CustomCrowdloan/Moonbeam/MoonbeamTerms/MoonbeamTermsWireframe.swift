import Foundation

final class MoonbeamTermsWireframe: MoonbeamTermsWireframeProtocol {
    func showContributionSetup(
        paraId: ParaId,
        moonbeamService: MoonbeamBonusServiceProtocol,
        state: CrowdloanSharedState,
        from view: ControllerBackedProtocol?
    ) {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(
            for: paraId,
            state: state,
            bonusService: moonbeamService
        ) else {
            return
        }

        let controller = setupView.controller
        controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
