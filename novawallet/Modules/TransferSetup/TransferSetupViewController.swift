import UIKit
import SoraFoundation
import CommonWallet

final class TransferSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = TransferSetupViewLayout

    let presenter: TransferSetupPresenterProtocol

    init(
        presenter: TransferSetupPresenterProtocol,
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
        view = TransferSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.recepientTitleLabel.text = R.string.localizable.commonRecipient(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.amountView.titleView.text = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.recepientInputView.locale = selectedLocale
        rootView.networkFeeView.locale = selectedLocale
    }
}

extension TransferSetupViewController: TransferSetupViewProtocol {
    func didReceiveChainAsset(viewModel: ChainAssetViewModel) {
        let assetViewModel = viewModel.assetViewModel
        rootView.tokenLabel.text = R.string.localizable.walletTransferTokenFormat(
            assetViewModel.symbol,
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.amountInputView.bind(assetViewModel: assetViewModel)

        let networkViewModel = viewModel.networkViewModel
        rootView.networkView.nameLabel.text = networkViewModel.name.uppercased()
        rootView.networkView.iconView.bind(gradient: networkViewModel.gradient)

        let imageSize = CGSize(width: 24.0, height: 24.0)
        rootView.networkView.iconView.bind(iconViewModel: networkViewModel.icon, size: imageSize)
    }

    func didReceiveTransferableBalance(viewModel: String) {
        let detailsTitleLabel = rootView.amountView.detailsTitleLabel
        let detailsValueLabel = rootView.amountView.detailsValueLabel

        detailsTitleLabel.text = R.string.localizable.commonTransferablePrefix(
            preferredLanguages: selectedLocale.rLanguages
        )

        detailsValueLabel.text = viewModel
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeView.bind(viewModel: viewModel)
    }

    func didReceiveAmount(inputViewModel _: AmountInputViewModelProtocol) {}
}

extension TransferSetupViewController: Localizable {
    func applyLocalization() {
        if isSetup {
            setupLocalization()
        }
    }
}
