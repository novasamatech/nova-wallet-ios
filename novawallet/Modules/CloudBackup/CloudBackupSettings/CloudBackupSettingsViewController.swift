import UIKit
import SoraFoundation

final class CloudBackupSettingsViewController: UIViewController, ViewHolder {
    typealias RootViewType = CloudBackupSettingsViewLayout

    let presenter: CloudBackupSettingsPresenterProtocol

    init(
        presenter: CloudBackupSettingsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CloudBackupSettingsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.cloudBackupActionControl.switchControl.addTarget(
            self,
            action: #selector(actionIcloudSwitch),
            for: .valueChanged
        )

        rootView.manualBackupActionControl.addTarget(
            self,
            action: #selector(actionManualBackup),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        title = R.string.localizable.commonBackup(preferredLanguages: selectedLocale.rLanguages)

        rootView.cloudBackupTitleLabel.text = R.string.localizable.commonCloudBackup(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.cloudBackupSubtitleLabel.text = R.string.localizable.backupSettingsCloudSubtitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.cloudBackupActionControl.titleLabel.text = R.string.localizable.commonBackupIcloud(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.manualBackupTitleLabel.text = R.string.localizable.commonManual(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.manualBackupSubtitleLabel.text = R.string.localizable.backupSettingsManualSubtitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.manualBackupActionControl.titleLabel.text = R.string.localizable.commonBackupManual(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    @objc func actionIcloudSwitch() {
        presenter.toggleICloudBackup()
    }

    @objc func actionManualBackup() {
        presenter.activateManualBackup()
    }
}

extension CloudBackupSettingsViewController: CloudBackupSettingsViewProtocol {}

extension CloudBackupSettingsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
