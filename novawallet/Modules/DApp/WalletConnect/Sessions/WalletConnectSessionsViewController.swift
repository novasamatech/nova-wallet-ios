import UIKit
import SoraFoundation

final class WalletConnectSessionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletConnectSessionsViewLayout

    let presenter: WalletConnectSessionsPresenterProtocol

    init(presenter: WalletConnectSessionsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletConnectSessionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.scanButton.addTarget(
            self,
            action: #selector(actionScan),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        title = R.string.localizable.commonWalletConnect(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.scanButton.imageWithTitleView?.title = R.string.localizable.walletConnectScanButton(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.scanButton.invalidateLayout()
    }

    @objc func actionScan() {
        presenter.showScan()
    }
}

extension WalletConnectSessionsViewController: WalletConnectSessionsViewProtocol {}

extension WalletConnectSessionsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
