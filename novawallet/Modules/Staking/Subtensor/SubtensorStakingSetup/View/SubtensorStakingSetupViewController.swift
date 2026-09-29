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
        rootView.receiveCell.titleLabel.text = strings.stakingSubtensorUiYouWillGet()
        rootView.swapRateCell.titleLabel.text = strings.stakingSubtensorUiSwapRate()
        rootView.slippageCell.titleLabel.text = strings.swapsSetupSlippage()
        rootView.networkFeeCell.rowContentView.locale = selectedLocale

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
        rootView.slippageCell.addTarget(self, action: #selector(actionSelectSlippage), for: .touchUpInside)
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

        switch viewModel {
        case .loading:
            cell.canSelect = false
            cell.bind(viewModel: nil)
        case let .unselected(title, canSelect):
            cell.canSelect = canSelect
            cell.bind(details: title)
        case let .selected(displayAddress, canSelect):
            cell.canSelect = canSelect
            cell.bind(
                viewModel: StackCellViewModel(
                    details: displayAddress.name ?? displayAddress.address,
                    imageViewModel: displayAddress.imageViewModel
                )
            )
        }

        if cell.canSelect {
            cell.accessoryImageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
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

    func applySlippage(_ viewModel: SubtensorSetupRowViewModel) {
        rootView.slippageCell.isHidden = viewModel == .hidden

        if case let .value(details) = viewModel {
            rootView.slippageCell.bind(details: details)
            rootView.slippageCell.accessoryImageView.image = R.image.iconSmallArrow()?.tinted(
                with: R.color.colorIconSecondary()!
            )
        }
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

    @objc func actionSelectSlippage() {
        presenter.selectSlippage()
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

        applyMax(viewModel.maxAmount, isAccented: viewModel.getTao != nil)
        applyGetTao(viewModel.getTao)

        rootView.reserveAlertView.isHidden = viewModel.reserveWarning == nil
        rootView.reserveAlertView.contentView.detailsLabel.text = viewModel.reserveWarning

        applyValidator(viewModel.validator)
        applyRow(viewModel.apy, cell: rootView.apyCell, skeletonView: rootView.apySkeletonView)
        applyRow(viewModel.receive, cell: rootView.receiveCell, skeletonView: nil)
        applyRow(viewModel.swapRate, cell: rootView.swapRateCell, skeletonView: nil)
        applySlippage(viewModel.slippage)
        applyNetworkFee(viewModel.networkFee)

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
