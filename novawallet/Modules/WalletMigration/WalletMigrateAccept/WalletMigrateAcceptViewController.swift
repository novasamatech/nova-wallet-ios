import UIKit
import Foundation_iOS

final class WalletMigrateAcceptViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletMigrateAcceptViewLayout

    let presenter: WalletMigrateAcceptPresenterProtocol

    init(presenter: WalletMigrateAcceptPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletMigrateAcceptViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }
}

private extension WalletMigrateAcceptViewController {
    func setupHandlers() {
        rootView.genericActionView.actionButton.addTarget(
            self,
            action: #selector(actionAccept),
            for: .touchUpInside
        )
    }

    func setupLocalization() {
        rootView.titleView.valueTop.text = R.string.localizable.walletMigrateAcceptTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.titleView.valueBottom.text = R.string.localizable.walletMigrateAcceptMessage(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.genericActionView.actionButton.setTitle(R.string.localizable.walletMigrateAcceptButton(
            preferredLanguages: selectedLocale.rLanguages
        ))
    }

    @objc func actionAccept() {}
}

extension WalletMigrateAcceptViewController: WalletMigrateAcceptViewProtocol {}

extension WalletMigrateAcceptViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
