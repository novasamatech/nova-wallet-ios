import Foundation_iOS
import UIKit

final class SubtensorStakingSetupViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = SubtensorStakingSetupViewLayout

    let presenter: SubtensorStakingSetupPresenterProtocol

    init(
        presenter: SubtensorStakingSetupPresenterProtocol,
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
        view = SubtensorStakingSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }
}

private extension SubtensorStakingSetupViewController {
    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.amountTitleView.titleLabel.text = strings.stakingSubtensorUiYouStake()
        rootView.amountTitleView.buttonTitle.text = strings.swapsSetupAssetMax()
        rootView.validatorCell.titleLabel.text = strings.stakingCommonValidator()
        rootView.apyCell.titleLabel.text = strings.stakingSubtensorUiValidatorSortApy()
        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        let cardView = rootView.pickCardView
        cardView.receiveCell.titleLabel.text = strings.stakingSubtensorUiYouWillGet()
        cardView.swapRateCell.titleLabel.text = strings.stakingSubtensorUiSwapRate()
        cardView.earnCell.titleLabel.text = strings.stakingSubtensorUiEarnTokensMonth()
        cardView.networkFeeCell.titleLabel.text = strings.commonNetworkFee()

        rootView.avgBuyPriceCell.titleLabel.text = strings.stakingSubtensorUiAvgBuyPrice()

        setupAmountInputAccessoryView()
    }

    func setupAmountInputAccessoryView() {
        let accessoryView = UIFactory.default.createAmountAccessoryView(for: self, locale: selectedLocale)

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    func setupHandlers() {
        rootView.amountTitleView.button.addTarget(self, action: #selector(actionMax), for: .touchUpInside)
        rootView.amountInputView.addTarget(self, action: #selector(actionAmountChange), for: .editingChanged)
        rootView.validatorCell.addTarget(self, action: #selector(actionSelectValidator), for: .touchUpInside)
        rootView.pickCardView.headerView.addTarget(self, action: #selector(actionCardHeader), for: .touchUpInside)
        rootView.pickCardView.swapRateCell.addTarget(self, action: #selector(actionSwapRateInfo), for: .touchUpInside)
        rootView.pickCardView.footerButton.addTarget(self, action: #selector(actionChooseMyself), for: .touchUpInside)
        rootView.avgBuyPriceCell.addTarget(self, action: #selector(actionAvgBuyPriceInfo), for: .touchUpInside)
        rootView.getTaoCardView.actionButton.addTarget(self, action: #selector(actionGetTao), for: .touchUpInside)
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
    }

    func applyMax(_ maxAmount: String?, isAccented: Bool) {
        let valueLabel = rootView.amountTitleView.buttonValue

        valueLabel.text = maxAmount
        valueLabel.apply(style: isAccented ? .footnoteAccentText : .footnotePrimary)
        rootView.amountTitleView.button.invalidateLayout()
        rootView.setSkeleton(
            rootView.maxSkeletonView,
            loading: maxAmount == nil,
            hiding: rootView.amountTitleView.button
        )
    }

    func applyGetTao(_ viewModel: SubtensorGetTaoViewModel?) {
        rootView.getTaoCardView.isHidden = viewModel == nil
        rootView.amountInputView.isHidden = viewModel != nil

        if let viewModel {
            rootView.getTaoCardView.bind(viewModel: viewModel)
        }
    }

    func applyValidator(_ viewModel: SubtensorSetupValidatorViewModel) {
        let cell = rootView.validatorCell

        var accessory = SubtensorSetupValidatorAccessory.chevron

        switch viewModel {
        case .loading:
            cell.canSelect = false
            cell.bind(viewModel: nil)
        case let .unselected(title):
            cell.canSelect = true
            cell.bind(details: title)
        case let .selected(displayAddress, validatorAccessory):
            cell.canSelect = true
            accessory = validatorAccessory
            cell.bind(
                viewModel: StackCellViewModel(
                    details: displayAddress.name ?? displayAddress.address,
                    imageViewModel: displayAddress.imageViewModel
                )
            )
        }

        if cell.canSelect {
            let image = accessory == .info ? R.image.iconInfoFilled() : R.image.iconSmallArrow()
            cell.accessoryImageView.image = image?.tinted(with: R.color.colorIconSecondary()!)
        }

        rootView.setSkeleton(
            rootView.validatorSkeletonView,
            loading: viewModel.isLoading,
            hiding: cell.rowContentView.valueView
        )
    }

    func applyRow(
        _ viewModel: SubtensorSetupRowViewModel,
        cell: StackTableCell,
        skeletonView: SubtensorChartLoadingView?
    ) {
        cell.isHidden = viewModel == .hidden

        if case let .value(details) = viewModel {
            cell.bind(details: details)
        }

        if let skeletonView {
            rootView.setSkeleton(skeletonView, loading: viewModel == .loading, hiding: cell.rowContentView.valueView)
        }
    }

    func applyDetails(_ details: SubtensorSetupDetailsViewModel) {
        switch details {
        case let .root(viewModel):
            rootView.detailsTableView.isHidden = false
            rootView.sectionLabel.isHidden = true
            rootView.pickCardView.isHidden = true
            rootView.feeDisclosureLabel.isHidden = true

            applyAvgBuyPrice(.hidden)
            applyValidator(viewModel.validator)
            applyRow(viewModel.apy, cell: rootView.apyCell, skeletonView: rootView.apySkeletonView)
            applyNetworkFee(viewModel.networkFee)
        case let .subnet(viewModel):
            rootView.detailsTableView.isHidden = true
            rootView.sectionLabel.isHidden = false
            rootView.pickCardView.isHidden = false
            rootView.feeDisclosureLabel.isHidden = false

            rootView.sectionLabel.text = viewModel.sectionTitle
            rootView.pickCardView.bind(viewModel: viewModel.card)
            rootView.feeDisclosureLabel.text = viewModel.feeDisclosure

            applyAvgBuyPrice(viewModel.avgBuyPrice)
        }
    }

    func applyAvgBuyPrice(_ viewModel: SubtensorCostBasisRowViewModel) {
        rootView.setAvgBuyPriceVisible(viewModel != .hidden)
        rootView.avgBuyPriceCell.bind(costBasisRow: viewModel)
    }

    func applySettings(_ hasSettings: Bool) {
        guard hasSettings else {
            navigationItem.rightBarButtonItem = nil
            return
        }

        guard navigationItem.rightBarButtonItem == nil else {
            return
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: R.image.iconSettings(),
            style: .plain,
            target: self,
            action: #selector(actionSettings)
        )
    }

    func applyNetworkFee(_ viewModel: BalanceViewModelProtocol?) {
        let feeView: NetworkFeeView = rootView.networkFeeCell.rowContentView

        feeView.bind(viewModel: viewModel ?? BalanceViewModel(amount: "", price: nil))
        rootView.setSkeleton(rootView.feeSkeletonView, loading: viewModel == nil, hiding: feeView.tokenLabel)
    }

    func applyAction(_ viewModel: SubtensorSetupActionViewModel) {
        if viewModel.isEnabled {
            rootView.actionButton.applyEnabledStyle()
        } else {
            rootView.actionButton.applyDisabledStyle()
        }

        rootView.actionButton.isUserInteractionEnabled = viewModel.isEnabled
        rootView.actionButton.imageWithTitleView?.title = viewModel.title
        rootView.actionButton.invalidateLayout()
    }

    @objc func actionMax() {
        presenter.selectMax()
    }

    @objc func actionAmountChange() {
        presenter.updateAmount(rootView.amountInputView.inputViewModel?.decimalAmount)
    }

    @objc func actionSelectValidator() {
        presenter.selectValidator()
    }

    @objc func actionCardHeader() {
        presenter.selectCardHeader()
    }

    @objc func actionSwapRateInfo() {
        presenter.showSwapRateInfo()
    }

    @objc func actionAvgBuyPriceInfo() {
        presenter.showAvgBuyPriceInfo()
    }

    @objc func actionChooseMyself() {
        presenter.chooseMyself()
    }

    @objc func actionSettings() {
        presenter.selectSettings()
    }

    @objc func actionGetTao() {
        presenter.getTao()
    }

    @objc func actionProceed() {
        presenter.proceed()
    }
}

extension SubtensorStakingSetupViewController: SubtensorStakingSetupViewProtocol {
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: inputViewModel)
    }

    func didReceiveAmountAsset(viewModel: AssetBalanceViewModelProtocol) {
        rootView.amountInputView.bind(
            assetViewModel: AssetViewModel(symbol: viewModel.symbol, imageViewModel: viewModel.iconViewModel)
        )

        rootView.amountInputView.bind(priceViewModel: viewModel.price)
        rootView.getTaoCardView.bind(iconViewModel: viewModel.iconViewModel)
    }

    func didReceive(viewModel: SubtensorStakingSetupViewModel) {
        title = viewModel.title

        applySettings(viewModel.hasSettings)

        rootView.amountTitleView.titleLabel.text = viewModel.amountTitle
        applyMax(viewModel.maxAmount, isAccented: viewModel.getTao != nil)
        applyGetTao(viewModel.getTao)

        rootView.reserveAlertView.isHidden = viewModel.reserveWarning == nil
        rootView.reserveAlertView.contentView.detailsLabel.text = viewModel.reserveWarning

        applyDetails(viewModel.details)

        rootView.holdAlertView.isHidden = viewModel.holdWarning == nil
        rootView.holdAlertView.contentView.detailsLabel.text = viewModel.holdWarning

        rootView.captionLabel.isHidden = viewModel.caption == nil
        rootView.captionLabel.text = viewModel.caption

        applyAction(viewModel.action)
    }
}

extension SubtensorStakingSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension SubtensorStakingSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
