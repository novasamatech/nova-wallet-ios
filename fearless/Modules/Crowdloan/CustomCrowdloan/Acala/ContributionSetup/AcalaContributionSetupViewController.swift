import UIKit
import SoraFoundation

final class AcalaContributionSetupViewController: CrowdloanContributionSetupViewController {
    typealias RootViewType = AcalaContributionSetupViewLayout

    let presenter: AcalaContributionSetupPresenterProtocol

    init(
        presenter: AcalaContributionSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(presenter: presenter, localizationManager: localizationManager)
    }

    override func loadView() {
        view = AcalaContributionSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        print("asdasd")
    }
}
