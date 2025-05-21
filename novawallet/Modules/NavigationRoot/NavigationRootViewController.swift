import UIKit

final class NavigationRootViewController: DecorateNavbarOnScrollController, ViewHolder {
    typealias RootViewType = NavigationRootViewLayout

    let presenter: NavigationRootPresenterProtocol

    init(
        scrollHost: ScrollViewHostControlling,
        presenter: NavigationRootPresenterProtocol,
        decorationProvider: ScrollDecorationProviding? = nil
    ) {
        self.presenter = presenter

        super.init(scrollHost: scrollHost, decorationProvider: decorationProvider)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NavigationRootViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()

        presenter.setup()
    }
}

private extension NavigationRootViewController {
    func setupNavigationItem() {
        rootView.titleView.addTarget(self, action: #selector(actionWallet), for: .touchUpInside)

        navigationItem.leftBarButtonItem = rootView.walletConnectBarItem

        rootView.walletConnectBarItem.target = self
        rootView.walletConnectBarItem.action = #selector(actionWalletConnect)

        navigationItem.rightBarButtonItem = rootView.settingsBarItem

        rootView.settingsBarItem.target = self
        rootView.settingsBarItem.action = #selector(actionSettings)
    }

    @objc func actionWalletConnect() {
        presenter.activateWalletConnect()
    }

    @objc func actionSettings() {
        presenter.activateSettings()
    }

    @objc func actionWallet() {
        presenter.activateWalletSelection()
    }
}

extension NavigationRootViewController: NavigationRootViewProtocol {
    func didReceive(walletSwitchViewModel: WalletSwitchViewModel) {
        rootView.titleView.bind(viewModel: walletSwitchViewModel)

        navigationItem.titleView = rootView.titleView
    }

    func didReceive(walletConnectSessions: Int) {
        if walletConnectSessions > 0 {
            rootView.walletConnectBarItem.image = R.image.iconWalletConnectActive()
        } else {
            rootView.walletConnectBarItem.image = R.image.iconWalletConnectNormal()
        }
    }
}

extension NavigationRootViewController: NavigationRootSettingsProtocol {
    func presentCloudBackupSettings() {
        presenter.activateCloudBackupSettings()
    }
}

extension NavigationRootViewController: ScrollsToTop {
    func scrollToTop() {
        (scrollHost as? ScrollsToTop)?.scrollToTop()
    }
}
