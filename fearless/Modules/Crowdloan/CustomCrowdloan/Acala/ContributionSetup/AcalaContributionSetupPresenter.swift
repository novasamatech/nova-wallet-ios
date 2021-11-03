import Foundation

final class AcalaContributionSetupPresenter: CrowdloanContributionSetupPresenter {
    var acalaService: AcalaBonusService? {
        bonusService as? AcalaBonusService
    }
}

extension AcalaContributionSetupPresenter: AcalaContributionSetupPresenterProtocol {
    func selectContributionMethod(_ method: AcalaContributionMethod) {
        print(method)
    }
}
