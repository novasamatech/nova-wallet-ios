import UIKit

final class StakingRebagConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRebagConfirmViewLayout

    let presenter: StakingRebagConfirmPresenterProtocol

    init(presenter: StakingRebagConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingRebagConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    // TODO: Localize
    private func setupLocalization() {
        title = "Staking improvements"
        rootView.walletCell.titleLabel.text = "Wallet"
        rootView.accountCell.titleLabel.text = "Account"
        rootView.currentBagList.titleLabel.text = "Current bag list"
        rootView.nextBagList.titleLabel.text = "New bag list"
        rootView.confirmButton.imageWithTitleView?.title = "Confirm"
    }

    private func setupHandlers() {
        rootView.confirmButton.addTarget(
            self,
            action: #selector(didTapOnConfirm),
            for: .touchUpInside
        )

        rootView.accountCell.addTarget(
            self,
            action: #selector(didTapOnSelectAccount),
            for: .touchUpInside
        )
    }

    @objc private func didTapOnConfirm() {
        presenter.confirm()
    }

    @objc private func didTapOnSelectAccount() {
        presenter.selectAccount()
    }
}

extension StakingRebagConfirmViewController: StakingRebagConfirmViewProtocol {
    func didReceiveWallet(viewModel: DisplayWalletViewModel) {
        rootView.walletCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveAccount(viewModel: DisplayAddressViewModel) {
        rootView.accountCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveNetworkFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveCurrentRebag(viewModel: String) {
        rootView.currentBagList.bind(details: viewModel)
    }

    func didReceiveNextRebag(viewModel: String) {
        rootView.nextBagList.bind(details: viewModel)
    }

    func didReceiveHints(viewModel: [String]) {
        rootView.hintView.bind(texts: viewModel)
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}
