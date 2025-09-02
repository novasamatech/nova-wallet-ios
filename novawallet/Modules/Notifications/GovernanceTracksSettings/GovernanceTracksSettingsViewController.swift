import UIKit
import Foundation_iOS

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
        let strings = R.string.localizable.self
        governanceTracksSettingsLayout?.tracksView.titleLabel.text = strings.notificationsManagementGovTracksTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}

extension GovernanceTracksSettingsViewController: GovernanceTracksSettingsViewProtocol {
    func didReceive(networkViewModel: NetworkViewModel) {
        governanceTracksSettingsLayout?.tracksView.networkView.bind(viewModel: networkViewModel)
    }
}
