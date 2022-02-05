import UIKit
import SoraFoundation
import SoraUI

final class DAppOperationConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppOperationConfirmViewLayout

    let presenter: DAppOperationConfirmPresenterProtocol

    init(presenter: DAppOperationConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        preferredContentSize = CGSize(width: 0.0, height: 522.0)
        self.localizationManager = localizationManager
    }

    private var viewModel: DAppOperationConfirmViewModel?

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppOperationConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.confirmButton.addTarget(self, action: #selector(actionConfirm), for: .touchUpInside)
        rootView.rejectButton.addTarget(self, action: #selector(actionReject), for: .touchUpInside)
        rootView.transactionDetailsControl.addTarget(self, action: #selector(actionTxDetails), for: .touchUpInside)
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.titleLabel.text = R.string.localizable.commonConfirmTitle(preferredLanguages: languages)
        rootView.subtitleLabel.text = R.string.localizable.dappConfirmSubtitle(preferredLanguages: languages)
        rootView.walletView.rowContentView.titleView.text = R.string.localizable.commonWallet(
            preferredLanguages: languages
        )
        rootView.accountAddressView.rowContentView.titleView.text = R.string.localizable.commonAccountAddress(
            preferredLanguages: languages
        )
        rootView.networkView.rowContentView.titleView.text = R.string.localizable.commonNetwork(
            preferredLanguages: languages
        )
        rootView.networkFeeView.titleLabel.text = R.string.localizable.commonNetworkFee(
            preferredLanguages: languages
        )
        rootView.transactionDetailsControl.rowContentView.titleView.text = R.string.localizable.commonTxDetails(
            preferredLanguages: languages
        )

        rootView.confirmButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: languages
        )
        rootView.rejectButton.imageWithTitleView?.title = R.string.localizable.commonReject(
            preferredLanguages: languages
        )
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionReject() {
        presenter.reject()
    }

    @objc private func actionTxDetails() {
        presenter.activateTxDetails()
    }
}

extension DAppOperationConfirmViewController: DAppOperationConfirmViewProtocol {
    func didReceive(confimationViewModel: DAppOperationConfirmViewModel) {
        let networkImageView = rootView.networkView.rowContentView.valueView.imageView
        viewModel?.networkIconViewModel?.cancel(on: networkImageView)

        viewModel = confimationViewModel

        rootView.iconView.bind(
            viewModel: viewModel?.iconImageViewModel,
            size: DAppOperationConfirmViewLayout.titleImageSize
        )

        rootView.walletView.rowContentView.valueView.detailsLabel.text = confimationViewModel.walletName

        let walletImageView = rootView.walletView.rowContentView.valueView.imageView
        walletImageView.image = confimationViewModel.walletIcon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: DAppOperationConfirmViewLayout.listImageSize,
            contentScale: UIScreen.main.scale
        )

        rootView.accountAddressView.rowContentView.valueView.detailsLabel.text = confimationViewModel.address

        let addressImageView = rootView.accountAddressView.rowContentView.valueView.imageView
        addressImageView.image = confimationViewModel.addressIcon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: DAppOperationConfirmViewLayout.listImageSize,
            contentScale: UIScreen.main.scale
        )

        rootView.networkView.rowContentView.valueView.detailsLabel.text = confimationViewModel.networkName

        networkImageView.image = nil

        confimationViewModel.networkIconViewModel?.loadImage(
            on: networkImageView,
            targetSize: DAppOperationConfirmViewLayout.listImageSize,
            animated: true
        )
    }

    func didReceive(feeViewModel: DAppOperationFeeViewModel) {
        switch feeViewModel {
        case .loading:
            rootView.networkFeeView.isHidden = false
            rootView.networkFeeView.bind(viewModel: nil)
        case .empty:
            rootView.networkFeeView.isHidden = true
        case let .loaded(value):
            rootView.networkFeeView.isHidden = false
            rootView.networkFeeView.bind(viewModel: value)
        }
    }
}

extension DAppOperationConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension DAppOperationConfirmViewController: ModalPresenterDelegate {
    func presenterShouldHide(_: ModalPresenterProtocol) -> Bool { false }

    func presenterDidHide(_: ModalPresenterProtocol) {}
}
