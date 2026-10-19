import Foundation_iOS
import UIKit

final class SubtensorConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorConfirmViewLayout

    let presenter: SubtensorConfirmPresenterProtocol
    let mode: SubtensorConfirmViewLayout.Mode

    init(
        presenter: SubtensorConfirmPresenterProtocol,
        mode: SubtensorConfirmViewLayout.Mode,
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
        view = SubtensorConfirmViewLayout()
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

private extension SubtensorConfirmViewController {
    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.priceMovedView.contentView.detailsLabel.text = strings.stakingSubtensorConfirmPriceMoved()

        rootView.swapRateCell.titleButton.setTitle(strings.stakingSubtensorUiSwapRate())
        rootView.slippageCell.titleButton.setTitle(strings.swapsSetupSlippage())
        rootView.validatorCell.titleButton.setTitle(strings.stakingCommonValidator())
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
        rootView.avgBuyPriceCell.addTarget(self, action: #selector(actionAvgBuyPriceInfo), for: .touchUpInside)
        rootView.youWillEarnCell.addTarget(self, action: #selector(actionYouWillEarnInfo), for: .touchUpInside)
        rootView.networkFeeCell.addTarget(self, action: #selector(actionNetworkFeeInfo), for: .touchUpInside)
    }

    func bindTile(_ tileView: SwapElementView, state: LoadableViewModelState<BalanceViewModel>) {
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

        tileView.assetIconView.imageView.layer.cornerRadius = size.width / 2
        tileView.assetIconView.imageView.clipsToBounds = true
        tileView.assetIconView.bind(viewModel: iconViewModel, size: size)
    }

    func bindSwap(_ viewModel: SubtensorConfirmSwapViewModel, networkFee: BalanceViewModelProtocol?) {
        bindTile(rootView.pairsView.leftAssetView, state: .loaded(value: viewModel.pay))
        bindTile(rootView.pairsView.rigthAssetView, state: viewModel.receive)

        rootView.swapRateCell.bind(loadableViewModel: viewModel.swapRate)
        rootView.swapRateCell.bind(attention: viewModel.isQuoteFailed ? .medium : .low)

        rootView.avgBuyPriceCell.bind(costBasisRow: viewModel.avgBuyPrice, locale: selectedLocale)
        rootView.youWillEarnCell.bind(costBasisRow: viewModel.youWillEarn, locale: selectedLocale)

        rootView.slippageCell.isHidden = viewModel.slippage == nil
        rootView.slippageCell.bind(loadableViewModel: .loaded(value: viewModel.slippage ?? ""))

        rootView.validatorCell.rowContentView.bind(apy: viewModel.validatorApy)

        let feeViewModel: LoadableViewModelState<NetworkFeeInfoViewModel> = networkFee.map {
            .loaded(value: NetworkFeeInfoViewModel(isEditable: false, balanceViewModel: $0))
        } ?? .loading

        rootView.networkFeeCell.bind(loadableViewModel: feeViewModel)

        rootView.feeDisclosureLabel.text = viewModel.feeDisclosure
        rootView.feeDisclosureLabel.isHidden = viewModel.feeDisclosure == nil
        rootView.remarkLabel.apply(text: viewModel.remark ?? "", lineHeight: Constants.remarkLineHeight)
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

    func bindAction(_ viewModel: SubtensorSetupActionViewModel) {
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

extension SubtensorConfirmViewController: SubtensorConfirmViewProtocol {
    func didReceiveWallet(viewModel: DisplayWalletViewModel) {
        rootView.walletCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveAccount(viewModel: DisplayAddressViewModel) {
        let address = viewModel.address.truncated(prefix: Constants.addressPrefix, suffix: Constants.addressSuffix)
        let cellViewModel = StackCellViewModel(details: address, imageViewModel: viewModel.imageViewModel)
        rootView.accountCell.bind(viewModel: cellViewModel)
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

        [rootView.detailsTableView, rootView.walletTableView, rootView.rootTableView].forEach {
            SubtensorDividerStyle.apply(to: $0)
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

extension SubtensorConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

private extension SubtensorConfirmViewController {
    enum Constants {
        static let remarkLineHeight: CGFloat = 16
        static let addressPrefix = 7
        static let addressSuffix = 5
    }
}
