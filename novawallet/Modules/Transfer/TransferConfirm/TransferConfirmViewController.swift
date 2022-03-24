import UIKit
import SoraFoundation

final class TransferConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = TransferConfirmViewLayout

    let presenter: TransferConfirmPresenterProtocol

    init(presenter: TransferConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TransferConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.walletSendTitle(preferredLanguages: selectedLocale.rLanguages)

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: selectedLocale.rLanguages)

        rootView.networkCell.titleLabel.text = R.string.localizable.commonNetwork(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.senderCell.titleLabel.text = R.string.localizable.commonSender(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        rootView.recepientCell.titleLabel.text = R.string.localizable.commonRecipient(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}

extension TransferConfirmViewController: TransferConfirmViewProtocol {
    func didReceiveNetwork(viewModel: NetworkViewModel) {
        rootView.networkCell.bind(viewModel: viewModel)
    }

    func didReceiveSender(viewModel: DisplayAddressViewModel) {
        rootView.senderCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveRecepient(viewModel: DisplayAddressViewModel) {
        rootView.recepientCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveWallet(viewModel: StackCellViewModel) {
        rootView.walletCell.bind(viewModel: viewModel)
    }

    func didReceiveAmount(viewModel _: BalanceViewModelProtocol) {}

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }
}

extension TransferConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
