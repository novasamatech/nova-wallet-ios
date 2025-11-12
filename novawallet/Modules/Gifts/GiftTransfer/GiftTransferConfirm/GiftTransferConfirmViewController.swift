import UIKit
import Foundation_iOS

final class GiftTransferConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftTransferConfirmViewLayout

    let presenter: GiftTransferConfirmPresenterProtocol

    init(
        presenter: GiftTransferConfirmPresenterProtocol,
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
        view = GiftTransferConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }
}

// MARK: - Private

private extension GiftTransferConfirmViewController {
    func setupHandlers() {
        rootView.genericActionView.actionButton.addTarget(
            self,
            action: #selector(actionSubmit),
            for: .touchUpInside
        )

        rootView.senderCell.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )
    }

    func setupLocalization() {
        let localizedStrings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        title = localizedStrings.commonGift()

        rootView.genericActionView.actionButton.imageWithTitleView?.title = localizedStrings.commonConfirm()

        rootView.networkCell.titleLabel.text = localizedStrings.commonNetwork()
        rootView.walletCell.titleLabel.text = localizedStrings.commonWallet()
        rootView.senderCell.titleLabel.text = localizedStrings.commonAccount()

        rootView.networkFeeCell.rowContentView.locale = selectedLocale
        rootView.networkFeeCell.rowContentView.title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonNetworkFee()
        }

        rootView.claimFeeCell.rowContentView.locale = selectedLocale
        rootView.claimFeeCell.rowContentView.title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.giftClaimFee()
        }

        rootView.tooltipLabel.text = localizedStrings.giftTransferConfirmTooltip()
    }

    @objc func actionSubmit() {
        presenter.submit()
    }

    @objc func actionSender() {
        presenter.showSenderActions()
    }
}

// MARK: - GiftTransferConfirmViewProtocol

extension GiftTransferConfirmViewController: GiftTransferConfirmViewProtocol {
    func didReceiveNetwork(viewModel: NetworkViewModel) {
        rootView.networkCell.bind(viewModel: viewModel)
    }

    func didReceiveSender(viewModel: DisplayAddressViewModel) {
        rootView.senderCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveWallet(viewModel: StackCellViewModel) {
        rootView.walletCell.bind(viewModel: viewModel)
    }

    func didReceiveSpendingAmount(viewModel: BalanceViewModelProtocol) {
        rootView.amountView.bind(viewModel: viewModel)
    }

    func didReceiveGiftAmount(viewModel: BalanceViewModelProtocol) {
        rootView.giftAmountCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveNetworkFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveClaimFee(viewModel: BalanceViewModelProtocol?) {
        rootView.claimFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didStartLoading() {
        rootView.genericActionView.startLoading()
    }

    func didStopLoading() {
        rootView.genericActionView.stopLoading()
    }
}

// MARK: - Localizable

extension GiftTransferConfirmViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
