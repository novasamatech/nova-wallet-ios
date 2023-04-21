import Foundation
import SoraKeystore

final class AcalaContributionSetupWireframe: CrowdloanContributionSetupWireframe {
    let acalaService: AcalaBonusService

    init(
        state: CrowdloanSharedState,
        acalaService: AcalaBonusService,
        settingsManager: SettingsManagerProtocol
    ) {
        self.acalaService = acalaService
        super.init(
            state: state,
            settingsManager: settingsManager
        )
    }

    override func showConfirmation(
        from view: CrowdloanContributionSetupViewProtocol?,
        paraId: ParaId,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol?
    ) {
        showConfirmation(
            from: view,
            method: acalaService.selectedContributionMethod,
            paraId: paraId,
            inputAmount: inputAmount,
            bonusService: bonusService
        )
    }

    private func showConfirmation(
        from view: CrowdloanContributionSetupViewProtocol?,
        method: AcalaContributionMethod,
        paraId: ParaId,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol?
    ) {
        guard let confirmationView = AcalaContributionConfirmViewFactory.createView(
            method: method,
            with: paraId,
            inputAmount: inputAmount,
            bonusService: bonusService,
            state: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmationView.controller, animated: true)
    }
}
