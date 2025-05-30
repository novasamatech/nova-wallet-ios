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

        setupNavigation()
        setupHandlers()
        setupLocalization()

        presenter.setup()
    }
}

private extension WalletMigrateAcceptViewController {
    func setupNavigation() {
        let rightBarButtonItem = UIBarButtonItem(customView: rootView.skipButton)
        navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    func setupHandlers() {
        rootView.genericActionView.actionButton.addTarget(
            self,
            action: #selector(actionAccept),
            for: .touchUpInside
        )

        rootView.skipButton.addTarget(
            self,
            action: #selector(actionSkip),
            for: .touchUpInside
        )
    }

    func setupLocalization() {
        rootView.skipButton.imageWithTitleView?.title = R.string.localizable.commonSkip(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.titleView.valueTop.text = R.string.localizable.walletMigrateAcceptTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.titleView.valueBottom.text = R.string.localizable.walletMigrateAcceptMessage(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.genericActionView.actionButton.setTitle(R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        ))
    }

    @objc func actionAccept() {
        presenter.accept()
    }

    @objc func actionSkip() {
        presenter.skip()
    }
}

extension WalletMigrateAcceptViewController: WalletMigrateAcceptViewProtocol {}

extension WalletMigrateAcceptViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
