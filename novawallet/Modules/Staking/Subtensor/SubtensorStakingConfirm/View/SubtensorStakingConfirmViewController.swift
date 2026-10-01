import Foundation_iOS
import UIKit

final class SubtensorStakingConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorStakingConfirmViewLayout

    let presenter: SubtensorStakingConfirmPresenterProtocol
    let mode: SubtensorStakingConfirmViewLayout.Mode

    init(
        presenter: SubtensorStakingConfirmPresenterProtocol,
        mode: SubtensorStakingConfirmViewLayout.Mode,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.mode = mode

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorStakingConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.setupMode(mode)
        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.didAppear()
    }
}

private extension SubtensorStakingConfirmViewController {
    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.priceMovedView.contentView.detailsLabel.text = strings.stakingSubtensorConfirmPriceMoved()

        rootView.swapRateCell.titleButton.setTitle(strings.stakingSubtensorUiSwapRate())
        rootView.slippageCell.titleButton.setTitle(strings.swapsSetupSlippage())
        rootView.validatorCell.titleButton.setTitle(strings.stakingCommonValidator())
        rootView.earnCell.titleButton.setTitle(strings.stakingSubtensorUiEarnTokensMonth())
        rootView.avgBuyPriceCell.titleButton.setTitle(strings.stakingSubtensorUiAvgBuyPrice())
        rootView.youWillEarnCell.titleButton.setTitle(strings.stakingSubtensorUiYouWillEarn())
        rootView.networkFeeCell.titleButton.setTitle(strings.commonNetworkFee())

        rootView.walletCell.titleLabel.text = strings.commonWallet()
        rootView.accountCell.titleLabel.text = strings.commonAccount()
        rootView.rootFeeCell.rowContentView.locale = selectedLocale

        rootView.stakingTypeCell.titleLabel.text = strings.stakingSubtensorUiStakingType()
        rootView.stakingTypeCell.bind(details: strings.stakingSubtensorUiRootStaking())
        rootView.stakeAfterCell.titleLabel.text = strings.stakingSubtensorUiStakeAfter()
        rootView.rootValidatorCell.titleLabel.text = strings.stakingCommonValidator()
        rootView.apyCell.titleLabel.text = strings.stakingSubtensorUiValidatorSortApy()
    }

    func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(actionConfirm), for: .touchUpInside)
        rootView.accountCell.addTarget(self, action: #selector(actionSelectAccount), for: .touchUpInside)
        rootView.validatorCell.addTarget(self, action: #selector(actionSelectValidator), for: .touchUpInside)
        rootView.rootValidatorCell.addTarget(self, action: #selector(actionSelectValidator), for: .touchUpInside)
        rootView.swapRateCell.addTarget(self, action: #selector(actionSwapRateInfo), for: .touchUpInside)
        rootView.slippageCell.addTarget(self, action: #selector(actionSlippageInfo), for: .touchUpInside)
        rootView.earnCell.addTarget(self, action: #selector(actionEarnInfo), for: .touchUpInside)
        rootView.avgBuyPriceCell.addTarget(self, action: #selector(actionAvgBuyPriceInfo), for: .touchUpInside)
        rootView.youWillEarnCell.addTarget(self, action: #selector(actionYouWillEarnInfo), for: .touchUpInside)
        rootView.networkFeeCell.addTarget(self, action: #selector(actionNetworkFeeInfo), for: .touchUpInside)
    }

    func bindTile(_ tileView: SwapElementView, state: LoadableViewModelState<SubtensorConfirmTileViewModel>) {
        if let viewModel = state.value {
            tileView.valueLabel.text = viewModel.amount
            tileView.priceLabel.text = viewModel.price ?? " "
        }

        switch state {
        case .loading, .cached:
            tileView.valueLabel.startShimmeringOpacity()
            tileView.priceLabel.startShimmeringOpacity()
        case .loaded:
            tileView.valueLabel.stopShimmeringOpacity()
            tileView.priceLabel.stopShimmeringOpacity()
        }
    }

    func bindIcon(_ iconViewModel: ImageViewModelProtocol?, on tileView: SwapElementView) {
        let insets = tileView.assetIconView.contentInsets
        let diameter = 2 * SwapElementView.assetIconRadius

        let size = CGSize(
            width: diameter - insets.left - insets.right,
            height: diameter - insets.top - insets.bottom
        )

        tileView.assetIconView.bind(viewModel: iconViewModel, size: size)
    }

    func bindCostBasisRow(_ viewModel: SubtensorCostBasisRowViewModel, cell: SwapNetworkFeeViewCell) {
        switch viewModel {
        case .hidden:
            cell.isHidden = true
        case .loading:
            cell.isHidden = false
            cell.bind(loadableViewModel: .loading)
        case let .value(value):
            cell.isHidden = false
            cell.valueTopButton.imageWithTitleView?.titleColor = value.tone.textColor

            let info = NetworkFeeInfoViewModel(
                isEditable: false,
                balanceViewModel: BalanceViewModel(amount: value.amount, price: value.detail)
            )

            cell.bind(loadableViewModel: .loaded(value: info))
        }
    }

    func bindSwap(_ viewModel: SubtensorConfirmSwapViewModel, networkFee: BalanceViewModelProtocol?) {
        bindTile(rootView.pairsView.leftAssetView, state: .loaded(value: viewModel.pay))
        bindTile(rootView.pairsView.rigthAssetView, state: viewModel.receive)

        rootView.swapRateCell.bind(loadableViewModel: viewModel.swapRate)

        bindCostBasisRow(viewModel.avgBuyPrice, cell: rootView.avgBuyPriceCell)
        bindCostBasisRow(viewModel.youWillEarn, cell: rootView.youWillEarnCell)

        rootView.slippageCell.isHidden = viewModel.slippage == nil
        rootView.slippageCell.bind(loadableViewModel: .loaded(value: viewModel.slippage ?? ""))

        rootView.validatorCell.rowContentView.bind(apy: viewModel.validatorApy)

        rootView.earnCell.isHidden = viewModel.earnPerMonth == nil

        if let earnPerMonth = viewModel.earnPerMonth {
            rootView.earnCell.bind(
                loadableViewModel: earnPerMonth.map { NetworkFeeInfoViewModel(isEditable: false, balanceViewModel: $0) }
            )
        }

        let feeViewModel: LoadableViewModelState<NetworkFeeInfoViewModel> = networkFee.map {
            .loaded(value: NetworkFeeInfoViewModel(isEditable: false, balanceViewModel: $0))
        } ?? .loading

        rootView.networkFeeCell.bind(loadableViewModel: feeViewModel)

        rootView.remarkLabel.text = viewModel.remark
        rootView.remarkLabel.isHidden = viewModel.remark == nil
    }

    func bindRoot(_ viewModel: SubtensorConfirmRootViewModel, networkFee: BalanceViewModelProtocol?) {
        rootView.amountView.bind(viewModel: viewModel.amount)
        rootView.rootFeeCell.rowContentView.bind(viewModel: networkFee)

        rootView.stakeAfterCell.isHidden = viewModel.stakeAfter == nil
        rootView.stakeAfterCell.bind(details: viewModel.stakeAfter ?? "")

        rootView.apyCell.isHidden = viewModel.apy == nil
        rootView.apyCell.bind(details: viewModel.apy ?? "")
    }

    func bindAction(_ viewModel: SubtensorConfirmActionViewModel) {
        rootView.actionButton.imageWithTitleView?.title = viewModel.title

        if viewModel.isEnabled {
            rootView.actionButton.applyEnabledStyle()
        } else {
            rootView.actionButton.applyDisabledStyle()
        }

        rootView.actionButton.isUserInteractionEnabled = viewModel.isEnabled
        rootView.actionButton.invalidateLayout()
    }

    func bindSigningHint(_ hint: String?) {
        rootView.signingHintView.isHidden = hint == nil

        if let hint {
            rootView.signingHintView.bindHint(text: hint, icon: R.image.iconWatchOnly())
        }
    }

    @objc func actionConfirm() {
        presenter.confirm()
    }

    @objc func actionSelectAccount() {
        presenter.selectAccount()
    }

    @objc func actionSelectValidator() {
        presenter.selectValidator()
    }

    @objc func actionSwapRateInfo() {
        presenter.showSwapRateInfo()
    }

    @objc func actionSlippageInfo() {
        presenter.showSlippageInfo()
    }

    @objc func actionEarnInfo() {
        presenter.showEarnPerMonthInfo()
    }

    @objc func actionAvgBuyPriceInfo() {
        presenter.showAvgBuyPriceInfo()
    }

    @objc func actionYouWillEarnInfo() {
        presenter.showYouWillEarnInfo()
    }

    @objc func actionNetworkFeeInfo() {
        presenter.showNetworkFeeInfo()
    }
}

extension SubtensorStakingConfirmViewController: SubtensorStakingConfirmViewProtocol {
    func didReceiveWallet(viewModel: DisplayWalletViewModel) {
        rootView.walletCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveAccount(viewModel: DisplayAddressViewModel) {
        rootView.accountCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveValidator(viewModel: DisplayAddressViewModel) {
        rootView.validatorCell.rowContentView.bind(viewModel: viewModel)

        rootView.rootValidatorCell.detailsLabel.lineBreakMode = viewModel.lineBreakMode
        rootView.rootValidatorCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveTileIcons(viewModel: SubtensorConfirmTileIconsViewModel) {
        bindIcon(viewModel.pay, on: rootView.pairsView.leftAssetView)
        bindIcon(viewModel.receive, on: rootView.pairsView.rigthAssetView)
    }

    func didReceive(viewModel: SubtensorConfirmViewModel) {
        title = viewModel.title

        switch viewModel.content {
        case let .swap(swapViewModel):
            bindSwap(swapViewModel, networkFee: viewModel.networkFee)
        case let .root(rootViewModel):
            bindRoot(rootViewModel, networkFee: viewModel.networkFee)
        }

        rootView.priceMovedView.isHidden = !viewModel.isPriceMoved

        bindAction(viewModel.action)
        bindSigningHint(viewModel.signingHint)
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension SubtensorStakingConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
