import UIKit
import Foundation_iOS

final class StakingConfirmProxyViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingConfirmProxyViewLayout

    let presenter: StakingConfirmProxyPresenterProtocol
    let localizableTitle: LocalizableResource<String>

    init(
        presenter: StakingConfirmProxyPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        title: LocalizableResource<String>
    ) {
        self.presenter = presenter
        localizableTitle = title
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingConfirmProxyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.networkCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.commonNetwork()
        rootView.proxiedWalletCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.stakingConfirmProxyWallet()
        rootView.proxiedAddressCell.titleLabel.text = R.string(preferredLanguages: languages).localizable.stakingConfirmProxyAccountProxied()
        rootView.proxyDepositView.titleButton.imageWithTitleView?.title = R.string(preferredLanguages: languages).localizable.stakingSetupProxyDeposit()
        rootView.feeCell.rowContentView.locale = selectedLocale
        rootView.actionButton.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: languages).localizable.commonConfirm()
        title = localizableTitle.value(for: selectedLocale)
    }

    private func setupHandlers() {
        rootView.proxiedAddressCell.addTarget(
            self,
            action: #selector(proxiedAddressAction),
            for: .touchUpInside
        )
        rootView.proxyAddressCell.addTarget(
            self,
            action: #selector(proxyAddressAction),
            for: .touchUpInside
        )
        rootView.proxyDepositView.addTarget(
            self,
            action: #selector(depositInfoAction),
            for: .touchUpInside
        )
        rootView.actionButton.actionButton.addTarget(
            self,
            action: #selector(confirmAction),
            for: .touchUpInside
        )
    }

    @objc private func proxiedAddressAction() {
        presenter.showProxiedAddressOptions()
    }

    @objc private func proxyAddressAction() {
        presenter.showProxyAddressOptions()
    }

    @objc private func depositInfoAction() {
        presenter.showDepositInfo()
    }

    @objc private func confirmAction() {
        presenter.confirm()
    }
}

extension StakingConfirmProxyViewController: StakingConfirmProxyViewProtocol {
    func didReceiveProxyDeposit(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>?) {
        if let viewModel = viewModel {
            rootView.proxyDepositView.isHidden = false
            rootView.proxyDepositView.bind(loadableViewModel: viewModel)
        } else {
            rootView.proxyDepositView.isHidden = true
        }
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.feeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveNetwork(viewModel: NetworkViewModel) {
        rootView.networkCell.bind(viewModel: viewModel)
    }

    func didReceiveWallet(viewModel: StackCellViewModel) {
        rootView.proxiedWalletCell.bind(viewModel: viewModel)
    }

    func didReceiveProxiedAddress(viewModel: DisplayAddressViewModel) {
        rootView.proxiedAddressCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveProxyAddress(title: String) {
        rootView.proxyAddressCell.titleLabel.text = title
    }

    func didReceiveProxyAddress(viewModel: DisplayAddressViewModel) {
        rootView.proxyAddressCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveProxyType(title: String) {
        rootView.proxyTypeCell.titleLabel.text = title
    }

    func didReceiveProxyType(viewModel: String) {
        rootView.proxyTypeCell.bind(details: viewModel)
    }

    func didStartLoading() {
        rootView.actionButton.startLoading()
    }

    func didStopLoading() {
        rootView.actionButton.stopLoading()
    }
}

extension StakingConfirmProxyViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            applyLocalization()
        }
    }
}
