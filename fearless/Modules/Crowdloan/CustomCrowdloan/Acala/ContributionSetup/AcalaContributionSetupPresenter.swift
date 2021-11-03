import Foundation
import BigInt

final class AcalaContributionSetupPresenter: CrowdloanContributionSetupPresenter {
    var acalaService: AcalaBonusService? {
        bonusService as? AcalaBonusService
    }

    private var minimumContributionLcDot: BigUInt?
}

extension AcalaContributionSetupPresenter: AcalaContributionSetupPresenterProtocol {
    var selectedContributionMethod: AcalaContributionMethod {
        acalaService?.selectedContributionMethod ?? .direct
    }

    func selectContributionMethod(_ method: AcalaContributionMethod) {
        acalaService?.selectedContributionMethod = method
        switch method {
        case .direct:
            if let minimumContribution = minimumContributionLcDot {
                self.minimumContribution = minimumContribution
            }
        case .liquid:
            minimumContributionLcDot = minimumContribution
            minimumContribution = BigUInt(1e+10)
        }
    }
}
