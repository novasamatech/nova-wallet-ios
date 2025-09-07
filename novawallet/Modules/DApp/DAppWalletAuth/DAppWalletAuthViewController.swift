import UIKit
import Foundation_iOS

final class DAppWalletAuthViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppWalletAuthViewLayout

    let presenter: DAppWalletAuthPresenterProtocol
    let localizableTitle: LocalizableResource<String>

    init(
        title: LocalizableResource<String>,
        presenter: DAppWalletAuthPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        localizableTitle = title
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppWalletAuthViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupStaticHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupStaticHandlers() {
        rootView.walletCell.addTarget(
            self,
            action: #selector(actionSelectWallet),
            for: .touchUpInside
        )

        rootView.networksCell.addTarget(
            self,
            action: #selector(actionShowNetworks),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = localizableTitle.value(for: selectedLocale)
        rootView.subtitleLabel.text = R.string(preferredLanguages: languages).localizable.dappAuthSubtitle()
        rootView.dappCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonDapp()

        setupButtonsLocalization()
    }

    private func setupButtonsLocalization() {
        rootView.approveButton?.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonAllow()

        rootView.rejectButton?.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonReject()
    }

    private func setupButtonsHandlers() {
        rootView.approveButton?.addTarget(
            self,
            action: #selector(actionApprove),
            for: .touchUpInside
        )

        rootView.rejectButton?.addTarget(
            self,
            action: #selector(actionReject),
            for: .touchUpInside
        )
    }

    @objc func actionApprove() {
        presenter.approve()
    }

    @objc func actionReject() {
        presenter.reject()
    }

    @objc func actionSelectWallet() {
        presenter.selectWallet()
    }

    @objc func actionShowNetworks() {
        presenter.showNetworks()
    }
}

extension DAppWalletAuthViewController: DAppWalletAuthViewProtocol {
    func didReceive(viewModel: DAppWalletAuthViewModel) {
        rootView.sourceAppIconView.bind(
            viewModel: viewModel.sourceImageViewModel,
            size: DAppIconLargeConstants.displaySize
        )

        rootView.destinationAppIconView.bind(
            viewModel: viewModel.destinationImageViewModel,
            size: DAppIconLargeConstants.displaySize
        )

        rootView.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.dappAuthTitle(viewModel.dAppName)

        rootView.dappCell.bind(details: viewModel.dAppHost)

        rootView.networksCell.bindNetworks(viewModel: viewModel.networks, locale: selectedLocale)

        rootView.applyNetworksWarning(text: viewModel.networksWarning)

        rootView.walletCell.bind(viewModel: viewModel.wallet)

        rootView.applyWalletWarning(text: viewModel.walletWarning)

        rootView.setupRejectButton()

        if viewModel.canApprove {
            rootView.setupApproveButton()
        } else {
            rootView.removeApproveButton()
        }

        setupButtonsLocalization()
        setupButtonsHandlers()
    }
}

extension DAppWalletAuthViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
