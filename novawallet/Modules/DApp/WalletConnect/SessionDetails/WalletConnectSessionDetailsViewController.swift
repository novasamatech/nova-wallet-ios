import UIKit
import Foundation_iOS

final class WalletConnectSessionViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletConnectSessionDetailsViewLayout

    let presenter: WalletConnectSessionDetailsPresenterProtocol

    init(
        presenter: WalletConnectSessionDetailsPresenterProtocol,
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
        view = WalletConnectSessionDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string(preferredLanguages: languages).localizable.commonWalletConnect()

        rootView.walletCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonWallet()

        rootView.dappCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonDapp()

        rootView.statusCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonStatus()

        rootView.actionLoadableView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: languages).localizable.commonDisconnect()
    }

    private func setupHandlers() {
        rootView.networksCell.addTarget(
            self,
            action: #selector(actionNetworks),
            for: .touchUpInside
        )

        rootView.actionLoadableView.actionButton.addTarget(
            self,
            action: #selector(actionDisconnect),
            for: .touchUpInside
        )
    }

    @objc func actionNetworks() {
        presenter.presentNetworks()
    }

    @objc func actionDisconnect() {
        presenter.disconnect()
    }
}

extension WalletConnectSessionViewController: WalletConnectSessionDetailsViewProtocol {
    func didReceive(viewModel: WalletConnectSessionViewModel) {
        rootView.bind(viewModel: viewModel, locale: selectedLocale)
    }
}

extension WalletConnectSessionViewController: LoadableViewProtocol {
    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension WalletConnectSessionViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
