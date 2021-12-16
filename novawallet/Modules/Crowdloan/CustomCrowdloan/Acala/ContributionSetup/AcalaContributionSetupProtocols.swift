import Foundation

protocol AcalaContributionSetupPresenterProtocol: CrowdloanContributionSetupPresenterProtocol {
    var selectedContributionMethod: AcalaContributionMethod { get }
    func selectContributionMethod(_ method: AcalaContributionMethod)
    func handleLearnMoreAboutContributions()
}
