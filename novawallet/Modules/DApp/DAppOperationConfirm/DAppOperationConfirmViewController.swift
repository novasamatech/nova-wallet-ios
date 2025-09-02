import UIKit
import Foundation_iOS
import UIKit_iOS

final class DAppOperationConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppOperationConfirmViewLayout

    let presenter: DAppOperationConfirmPresenterProtocol

    init(presenter: DAppOperationConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

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
        rootView.accountCell.addTarget(self, action: #selector(actionShowAccountOptions), for: .touchUpInside)
        rootView.confirmButton.addTarget(self, action: #selector(actionConfirm), for: .touchUpInside)
        rootView.rejectButton.addTarget(self, action: #selector(actionReject), for: .touchUpInside)
        rootView.transactionDetailsCell.addTarget(self, action: #selector(actionTxDetails), for: .touchUpInside)
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.dappsRequestSignTitle(preferredLanguages: languages)

        rootView.titleLabel.text = R.string.localizable.commonConfirmTitle(preferredLanguages: languages)
        rootView.subtitleLabel.text = R.string.localizable.dappConfirmSubtitle(preferredLanguages: languages)
        rootView.dAppCell.titleLabel.text = R.string.localizable.commonDapp(preferredLanguages: languages)
        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: languages
        )
        rootView.accountCell.titleLabel.text = R.string.localizable.commonAccountAddress(
            preferredLanguages: languages
        )
        rootView.networkCell.titleLabel.text = R.string.localizable.commonNetwork(
            preferredLanguages: languages
        )

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.transactionDetailsCell.titleLabel.text = R.string.localizable.commonTxDetails(
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

    @objc func actionShowAccountOptions() {
        presenter.showAccountOptions()
    }
}

extension DAppOperationConfirmViewController: DAppOperationConfirmViewProtocol {
    func didReceive(confirmationViewModel: DAppOperationConfirmViewModel) {
        rootView.dAppCell.bind(details: confirmationViewModel.dApp)

        rootView.iconView.bind(
            viewModel: confirmationViewModel.iconImageViewModel,
            size: DAppIconLargeConstants.displaySize
        )

        rootView.walletCell.bind(viewModel: .init(
            details: confirmationViewModel.walletName,
            imageViewModel: confirmationViewModel.walletIcon.map { DrawableIconViewModel(icon: $0) }
        ))

        rootView.accountCell.bind(viewModel: .init(
            details: confirmationViewModel.address,
            imageViewModel: confirmationViewModel.addressIcon.map { DrawableIconViewModel(icon: $0) }
        ))

        var networkCell: StackCellViewModel?

        if let networkModel = confirmationViewModel.network {
            networkCell = StackCellViewModel(
                details: networkModel.name,
                imageViewModel: networkModel.iconViewModel
            )
        }

        rootView.setupNetworkCell(with: networkCell)
    }

    func didReceive(feeViewModel: DAppOperationFeeViewModel) {
        switch feeViewModel {
        case .loading:
            rootView.feeCell.isHidden = false
            rootView.feeCell.rowContentView.bind(viewModel: nil)
        case .empty:
            rootView.feeCell.isHidden = true
        case let .loaded(value):
            rootView.feeCell.isHidden = false
            rootView.feeCell.rowContentView.bind(viewModel: value)
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

extension DAppOperationConfirmViewController: ModalCardPresentationControllerDelegate {
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        false
    }
}
