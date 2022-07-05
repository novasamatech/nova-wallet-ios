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
        setupHandlers()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.actionLoadableView.actionButton.addTarget(
            self,
            action: #selector(actionSubmit),
            for: .touchUpInside
        )

        rootView.senderCell.addTarget(
            self,
            action: #selector(actionSender),
            for: .touchUpInside
        )

        rootView.recepientCell.addTarget(
            self,
            action: #selector(actionRecepient),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        title = R.string.localizable.walletSendTitle(preferredLanguages: selectedLocale.rLanguages)

        rootView.actionLoadableView.actionButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: selectedLocale.rLanguages)

        if rootView.destinationNetworkCell == nil {
            rootView.originNetworkCell.titleLabel.text = R.string.localizable.commonNetwork(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            rootView.originNetworkCell.titleLabel.text = R.string.localizable.commonFromNetwork(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        rootView.destinationNetworkCell?.titleLabel.text = R.string.localizable.commonToNetwork(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.senderCell.titleLabel.text = R.string.localizable.commonSender(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.originFeeCell.rowContentView.locale = selectedLocale

        rootView.crossChainFeeCell?.rowContentView.locale = selectedLocale

        if let hintView = rootView.crossChainHintView {
            let hint = R.string.localizable.transferCrossChainHint(preferredLanguages: selectedLocale.rLanguages)
            hintView.bind(texts: [hint])
        }

        rootView.recepientCell.titleLabel.text = R.string.localizable.commonRecipient(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    @objc func actionSubmit() {
        presenter.submit()
    }

    @objc func actionSender() {
        presenter.showSenderActions()
    }

    @objc func actionRecepient() {
        presenter.showRecepientActions()
    }
}

extension TransferConfirmViewController: TransferConfirmCrossChainViewProtocol, TransferConfirmOnChainViewProtocol {
    func didReceiveOriginNetwork(viewModel: NetworkViewModel) {
        rootView.originNetworkCell.bind(viewModel: viewModel)
    }

    func didReceiveDestinationNetwork(viewModel: NetworkViewModel) {
        rootView.switchCrossChain()

        rootView.destinationNetworkCell?.bind(viewModel: viewModel)

        setupLocalization()
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

    func didReceiveAmount(viewModel: BalanceViewModelProtocol) {
        rootView.amountView.bind(viewModel: viewModel)
    }

    func didReceiveOriginFee(viewModel: BalanceViewModelProtocol?) {
        rootView.originFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveCrossChainFee(viewModel: BalanceViewModelProtocol?) {
        rootView.crossChainFeeCell?.rowContentView.bind(viewModel: viewModel)
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension TransferConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
