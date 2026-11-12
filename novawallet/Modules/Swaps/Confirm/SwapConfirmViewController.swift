import UIKit
import Foundation_iOS

final class SwapConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapConfirmViewLayout

    let presenter: SwapConfirmPresenterProtocol

    init(
        presenter: SwapConfirmPresenterProtocol,
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
        view = SwapConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    private func setupLocalization() {
        rootView.setup(locale: selectedLocale)
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSwapTitle()
    }

    private func setupHandlers() {
        rootView.rateCell.addTarget(self, action: #selector(rateAction), for: .touchUpInside)
        rootView.routeCell.addTarget(self, action: #selector(routeAction), for: .touchUpInside)
        rootView.slippageCell.addTarget(self, action: #selector(slippageAction), for: .touchUpInside)
        rootView.networkFeeCell.addTarget(self, action: #selector(networkFeeAction), for: .touchUpInside)
        rootView.accountCell.addTarget(self, action: #selector(addressAction), for: .touchUpInside)
        rootView.loadableActionView.actionButton.addTarget(self, action: #selector(confirmAction), for: .touchUpInside)
    }

    @objc private func rateAction() {
        presenter.showRateInfo()
    }

    @objc private func slippageAction() {
        presenter.showSlippageInfo()
    }

    @objc private func networkFeeAction() {
        presenter.showNetworkFeeInfo()
    }

    @objc private func routeAction() {
        presenter.showRouteDetails()
    }

    @objc private func addressAction() {
        presenter.showAddressOptions()
    }

    @objc private func confirmAction() {
        presenter.confirm()
    }
}

extension SwapConfirmViewController: SwapConfirmViewProtocol {
    func didReceiveAssetIn(viewModel: SwapAssetAmountViewModel) {
        rootView.pairsView.payCardView.bind(viewModel: viewModel)
    }

    func didReceiveAssetOut(viewModel: LoadableViewModelState<SwapAssetAmountViewModel>) {
        rootView.pairsView.receiveCardView.bind(loadableViewModel: viewModel)
    }

    func didReceiveRate(viewModel: LoadableViewModelState<String>) {
        rootView.rateCell.bind(loadableViewModel: viewModel)
    }

    func didReceiveRoute(viewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>) {
        rootView.routeCell.bind(loadableRouteViewModel: viewModel)
    }

    func didReceiveExecutionTime(viewModel: LoadableViewModelState<String>) {
        rootView.execTimeCell.bind(loadableViewModel: viewModel)
    }

    func didReceivePriceDifference(viewModel _: LoadableViewModelState<DifferenceViewModel>?) {}

    func didReceiveSlippage(viewModel: String) {
        rootView.slippageCell.bind(loadableViewModel: .loaded(value: viewModel))
    }

    func didReceiveNetworkFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        rootView.networkFeeCell.bind(loadableFeeViewModel: viewModel)
    }

    func didReceiveWallet(viewModel: WalletAccountViewModel?) {
        guard let viewModel else {
            rootView.walletTableView.isHidden = true
            return
        }

        rootView.walletTableView.isHidden = false
        rootView.walletCell.bind(details: viewModel.walletName ?? "", iconViewModel: nil)
        rootView.accountCell.bind(details: viewModel.address.truncated, iconViewModel: viewModel.addressIcon)
    }

    func didReceiveCommissionDisclosure(viewModel: String?) {
        rootView.set(commissionDisclosure: viewModel)
    }

    func didReceiveWarning(viewModel: String?) {
        rootView.set(warning: viewModel)
    }

    func didReceiveStartLoading() {
        rootView.loadableActionView.startLoading()
    }

    func didReceiveStopLoading() {
        rootView.loadableActionView.stopLoading()
    }
}

extension SwapConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
