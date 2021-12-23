import UIKit
import SoraFoundation

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
    }

    private func setupLocalization() {
        rootView.titleLabel.text = "Confirmation"
        rootView.subtitleLabel.text = "Approve this request if you trust the application.\nCheck transaction details."
        rootView.walletView.rowContentView.titleView.text = "Wallet"
        rootView.accountAddressView.rowContentView.titleView.text = "Account address"
        rootView.networkView.rowContentView.titleView.text = "Network"
        rootView.networkFeeView.titleLabel.text = "Transaction fee"
        rootView.transactionDetailsControl.rowContentView.titleView.text = "Transaction details"

        rootView.confirmButton.imageWithTitleView?.title = "Confirm"
        rootView.rejectButton.imageWithTitleView?.title = "Reject"
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionReject() {
        presenter.reject()
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

    func didReceive(feeViewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeView.bind(viewModel: feeViewModel)
    }
}

extension DAppOperationConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
