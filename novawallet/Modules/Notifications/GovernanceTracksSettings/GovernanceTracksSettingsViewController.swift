import UIKit
import SoraFoundation

final class GovernanceTracksSettingsViewController: GovernanceSelectTracksViewController {
    var governanceTracksSettingsLayout: GovernanceTracksSettingsViewLayout? {
        rootView as? GovernanceTracksSettingsViewLayout
    }

    override func loadView() {
        view = GovernanceTracksSettingsViewLayout()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        basePresenter.proceed()
    }

    override func setupLocalization() {
        super.setupLocalization()
        governanceTracksSettingsLayout?.tracksView.titleLabel.text = R.string.localizable.notificationsManagementGovTracksTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}

extension GovernanceTracksSettingsViewController: GovernanceTracksSettingsViewProtocol {
    func didReceive(networkViewModel: NetworkViewModel) {
        governanceTracksSettingsLayout?.tracksView.networkView.bind(viewModel: networkViewModel)
    }
}
