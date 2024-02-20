import UIKit
import SoraFoundation

final class GovernanceTracksSettingsViewController: GovernanceSelectTracksViewController {
    var presenter: GovernanceTracksSettingsPresenterProtocol? {
        basePresenter as? GovernanceTracksSettingsPresenterProtocol
    }

    var governanceTracksSettingsLayout: GovernanceTracksSettingsViewLayout? {
        rootView as? GovernanceTracksSettingsViewLayout
    }

    init(
        presenter: GovernanceTracksSettingsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        super.init(
            basePresenter: presenter,
            localizationManager: localizationManager
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceTracksSettingsViewLayout()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter?.proceed()
    }

    override func setupLocalization() {
        super.setupLocalization()
        governanceTracksSettingsLayout?.govTitleLabel.text = R.string.localizable.notificationsManagementGovTracksTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}

extension GovernanceTracksSettingsViewController: GovernanceTracksSettingsViewProtocol {
    func didReceive(networkViewModel: NetworkViewModel) {
        governanceTracksSettingsLayout?.networkView.bind(viewModel: networkViewModel)
    }
}
