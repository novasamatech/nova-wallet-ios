import UIKit
import Foundation_iOS

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.becomeActive()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        presenter.becomeInactive()
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

        rootView.settingsView.delegate = self
    }

    private func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonBackup()

        rootView.cloudBackupTitleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonIcloud()

        rootView.cloudBackupSubtitleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.backupSettingsCloudSubtitle()

        rootView.cloudBackupActionControl.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonBackupIcloud()

        rootView.manualBackupTitleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonManual()

        rootView.manualBackupSubtitleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.backupSettingsManualSubtitle()

        rootView.manualBackupActionControl.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonBackupManual()
    }

    @objc func actionIcloudSwitch() {
        presenter.toggleICloudBackup()
    }

    @objc func actionManualBackup() {
        presenter.activateManualBackup()
    }
}

extension CloudBackupSettingsViewController: CloudBackupSettingsViewProtocol {
    func didReceive(viewModel: CloudBackupSettingsViewModel) {
        rootView.settingsView.bind(viewModel: viewModel)

        rootView.cloudBackupActionControl.switchControl.isOn = viewModel.status.isEnabled
    }
}

extension CloudBackupSettingsViewController: CloudBackupSettingsViewDelegate {
    func didSelectSyncAction() {
        presenter.activateSyncAction()
    }

    func didSelectIssueAction() {
        presenter.activateSyncIssue()
    }
}

extension CloudBackupSettingsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
