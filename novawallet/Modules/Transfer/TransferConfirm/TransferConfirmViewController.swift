import UIKit
import SoraFoundation

final class TransferConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = TransferConfirmViewLayout

    let presenter: TransferConfirmPresenterProtocol

    init(presenter: TransferConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TransferConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.walletSendTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension TransferConfirmViewController: TransferConfirmViewProtocol {}

extension TransferConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
