import UIKit

final class WalletConnectViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletConnectViewLayout

    let presenter: WalletConnectPresenterProtocol

    init(presenter: WalletConnectPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletConnectViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupScanItem()
        setupLocalization()

        presenter.setup()
    }

    private func setupScanItem() {
        navigationItem.rightBarButtonItem = rootView.scanItem

        rootView.scanItem.target = self
        rootView.scanItem.action = #selector(actionScan)
    }

    private func setupLocalization() {
        title = "Your sessions"
    }

    @objc func actionScan() {
        presenter.showScan()
    }
}

extension WalletConnectViewController: WalletConnectViewProtocol {}
