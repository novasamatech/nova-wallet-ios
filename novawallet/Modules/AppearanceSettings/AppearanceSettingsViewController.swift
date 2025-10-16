import UIKit
import Foundation_iOS

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
        setupActions()
        presenter.setup()
    }
}

// MARK: Private

private extension AppearanceSettingsViewController {
    func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.settingsAppearance()

        rootView.locale = selectedLocale
    }

    func setupActions() {
        rootView.tokenIconsView.addAction { [weak self] newOption in
            self?.presenter.changeTokenIcons(with: newOption)
        }
    }
}

// MARK: AppearanceSettingsViewProtocol

extension AppearanceSettingsViewController: AppearanceSettingsViewProtocol {
    func update(with initialViewModel: AppearanceSettingsIconsView.Model) {
        rootView.tokenIconsView.bind(viewModel: initialViewModel)
    }
}

// MARK: Localizable

extension AppearanceSettingsViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
