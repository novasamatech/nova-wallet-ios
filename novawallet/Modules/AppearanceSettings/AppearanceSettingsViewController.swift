import UIKit
import SoraFoundation

final class AppearanceSettingsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AppearanceSettingsViewLayout

    let presenter: AppearanceSettingsPresenterProtocol

    init(
        presenter: AppearanceSettingsPresenterProtocol,
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
        view = AppearanceSettingsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.settingsAppearance(preferredLanguages: selectedLocale)
        rootView.locale = selectedLocale
    }
}

extension AppearanceSettingsViewController: AppearanceSettingsViewProtocol {}

// MARK: Localizable

extension AppearanceSettingsViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
