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

        title = R.string(preferredLanguages: languages).localizable.dappsRequestSignTitle()

        rootView.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonConfirmTitle()
        rootView.subtitleLabel.text = R.string(preferredLanguages: languages).localizable.dappConfirmSubtitle()
        rootView.dAppCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonDapp()
        rootView.walletCell.titleLabel.text = R.string(preferredLanguages: languages
        ).localizable.commonWallet()
        rootView.accountCell.titleLabel.text = R.string(preferredLanguages: languages
        ).localizable.commonAccountAddress()
        rootView.networkCell.titleLabel.text = R.string(preferredLanguages: languages
        ).localizable.commonNetwork()

        rootView.feeCell.rowContentView.locale = selectedLocale

        rootView.transactionDetailsCell.titleLabel.text = R.string(preferredLanguages: languages
        ).localizable.commonTxDetails()

        rootView.confirmButton.imageWithTitleView?.title = R.string(preferredLanguages: languages
        ).localizable.commonConfirm()
        rootView.rejectButton.imageWithTitleView?.title = R.string(preferredLanguages: languages
        ).localizable.commonReject()
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
