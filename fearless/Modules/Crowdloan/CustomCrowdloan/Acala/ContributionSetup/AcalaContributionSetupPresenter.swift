import Foundation

final class AcalaContributionSetupPresenter: CrowdloanContributionSetupPresenter {
    var acalaService: AcalaBonusService? {
        bonusService as? AcalaBonusService
    }
}

extension AcalaContributionSetupPresenter: AcalaContributionSetupPresenterProtocol {
    var selectedContributionMethod: AcalaContributionMethod {
        acalaService?.selectedContributionMethod ?? .direct
    }

    func selectContributionMethod(_ method: AcalaContributionMethod) {
        acalaService?.selectedContributionMethod = method
    }
}
