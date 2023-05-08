import UIKit
import SoraFoundation

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

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = localizableTitle.value(for: selectedLocale)
        rootView.subtitleLabel.text = R.string.localizable.dappAuthSubtitle(preferredLanguages: languages)
        rootView.dappCell.titleLabel.text = R.string.localizable.commonDapp(preferredLanguages: languages)
    }

    private func setupButtonsLocalization() {
        rootView.approveButton?.imageWithTitleView?.title = R.string.localizable.commonAllow(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.rejectButton?.imageWithTitleView?.title = R.string.localizable.commonReject(
            preferredLanguages: selectedLocale.rLanguages
        )
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

        rootView.titleLabel.text = R.string.localizable.dappAuthTitle(
            viewModel.dAppName,
            preferredLanguages: selectedLocale.rLanguages
        )

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
