import UIKit
import Foundation_iOS

final class StakingRebagConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRebagConfirmViewLayout

    let presenter: StakingRebagConfirmPresenterProtocol

    init(
        presenter: StakingRebagConfirmPresenterProtocol,
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
        view = StakingRebagConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    private func setupLocalization() {
        let strings = R.string.localizable.self
        title = strings.stakingImprovements(preferredLanguages: selectedLocale.rLanguages)
        rootView.walletCell.titleLabel.text = strings.commonWallet(preferredLanguages: selectedLocale.rLanguages)
        rootView.accountCell.titleLabel.text = strings.commonAccount(preferredLanguages: selectedLocale.rLanguages)
        rootView.currentBagList.titleLabel.text = strings.stakingRebagConfirmCurrentBagList(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.newBagList.titleLabel.text = strings.stakingRebagConfirmNewBagList(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.confirmButton.imageWithTitleView?.title = strings.commonConfirm(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupHandlers() {
        rootView.actionLoadableView.actionButton.addTarget(
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

    func didReceiveNetworkFee(viewModel: LoadableViewModelState<BalanceViewModelProtocol?>) {
        switch viewModel {
        case .loading:
            rootView.networkFeeCell.rowContentView.activityIndicator.startAnimating()
        case let .cached(value), let .loaded(value):
            rootView.networkFeeCell.rowContentView.activityIndicator.stopAnimating()
            rootView.networkFeeCell.rowContentView.bind(viewModel: value)
        }
    }

    func didReceiveCurrentRebag(viewModel: String) {
        rootView.didReceiveCurrentBagList(viewModel: viewModel)
    }

    func didReceiveNextRebag(viewModel: String) {
        rootView.didReceiveNewBagList(viewModel: viewModel)
    }

    func didReceiveHints(viewModel: [String]) {
        rootView.hintView.bind(texts: viewModel)
    }

    func didReceiveConfirmState(isAvailable: Bool) {
        rootView.actionLoadableView.actionButton.set(enabled: isAvailable)
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension StakingRebagConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
