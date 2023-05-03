import UIKit

final class WalletConnectSessionsViewController: UIViewController {
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

        presenter.setup()
    }

    private func setupHandlers() {}

    private func setupLocalization() {
        title = "Your sessions"
    }

    @objc func actionScan() {
        presenter.showScan()
    }
}

extension WalletConnectSessionsViewController: WalletConnectSessionsViewProtocol {}
