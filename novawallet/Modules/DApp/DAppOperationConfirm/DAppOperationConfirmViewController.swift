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

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppOperationConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        setupLocalization()
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
}

extension DAppOperationConfirmViewController: DAppOperationConfirmViewProtocol {}

extension DAppOperationConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
