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

        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.commonBackup(preferredLanguages: selectedLocale.rLanguages)
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
