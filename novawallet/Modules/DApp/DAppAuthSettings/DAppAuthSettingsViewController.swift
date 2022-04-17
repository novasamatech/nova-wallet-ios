import UIKit
import SoraFoundation

final class DAppAuthSettingsViewController: UIViewController {
    typealias RootViewType = DAppAuthSettingsViewLayout

    let presenter: DAppAuthSettingsPresenterProtocol

    init(presenter: DAppAuthSettingsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppAuthSettingsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {}
}

extension DAppAuthSettingsViewController: DAppAuthSettingsViewProtocol {
    func didReceiveWallet(viewModel _: DisplayWalletViewModel) {}

    func didReceiveAuthorized(viewModels _: [DAppAuthSettingsViewModel]) {}
}

extension DAppAuthSettingsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
