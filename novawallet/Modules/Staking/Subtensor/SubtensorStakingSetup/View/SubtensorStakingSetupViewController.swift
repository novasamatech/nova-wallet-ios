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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.didAppear()
    }
}

private extension SubtensorStakingSetupViewController {
    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.amountTitleView.titleLabel.text = strings.stakingSubtensorUiYouStake()
        rootView.amountTitleView.buttonTitle.text = strings.swapsSetupAssetMax()
        rootView.networkFeeCell.rowContentView.locale = selectedLocale
        rootView.validatorCell.titleLabel.text = strings.stakingCommonValidator()
        rootView.apyCell.titleLabel.text = strings.stakingSubtensorUiValidatorSortApy()

        let cardView = rootView.pickCardView
        cardView.validatorCell.titleLabel.text = strings.stakingCommonValidator()
        cardView.receiveCell.titleLabel.text = strings.stakingSubtensorUiYouWillGet()
        cardView.swapRateCell.titleLabel.text = strings.stakingSubtensorUiSwapRate()
        cardView.networkFeeCell.titleLabel.text = strings.commonNetworkFee()

        let skeletonView = rootView.pickSkeletonView
        skeletonView.receiveTitleLabel.text = strings.stakingSubtensorUiYouWillGet()
        skeletonView.swapRateTitleLabel.text = strings.stakingSubtensorUiSwapRate()
        skeletonView.networkFeeTitleLabel.text = strings.commonNetworkFee()

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
        rootView.validatorCardView.addTarget(self, action: #selector(actionSelectValidator), for: .touchUpInside)
        rootView.validatorCell.addTarget(self, action: #selector(actionSelectValidator), for: .touchUpInside)
        rootView.pickCardView.headerView.addTarget(self, action: #selector(actionCardHeader), for: .touchUpInside)
        rootView.pickCardView.swapRateCell.addTarget(self, action: #selector(actionSwapRateInfo), for: .touchUpInside)
        rootView.avgBuyPriceCell.addTarget(self, action: #selector(actionAvgBuyPriceInfo), for: .touchUpInside)
        rootView.getTaoCardView.actionButton.addTarget(self, action: #selector(actionGetTao), for: .touchUpInside)
        rootView.pickCardView.validatorCell.addTarget(
            self, action: #selector(actionSelectValidator), for: .touchUpInside
        )
        rootView.pickCardView.browseView.button.addTarget(self, action: #selector(actionBrowse), for: .touchUpInside)
        rootView.browseView.button.addTarget(self, action: #selector(actionBrowse), for: .touchUpInside)
        rootView.selectionAlert.learnMoreButton.addTarget(self, action: #selector(actionRetry), for: .touchUpInside)
        rootView.actionButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)
    }

    func applyMax(_ maxAmount: String?, isAccented: Bool) {
        let valueLabel = rootView.amountTitleView.buttonValue

        valueLabel.text = maxAmount
        valueLabel.apply(style: isAccented ? .regularSubhedlineAccent : .regularSubhedlinePrimary)
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

    func applyDetails(_ details: SubtensorSetupDetailsViewModel) {
        rootView.setSelection(details.selection)
        switch details {
        case let .selection(viewModel):
            rootView.detailsTableView.isHidden = true
            rootView.pickCardView.isHidden = true
            rootView.browseView.isHidden = true
            rootView.sectionLabel.isHidden = false
            rootView.setSection(viewModel.section)
            applyAvgBuyPrice(.hidden)
        case let .root(viewModel):
            rootView.detailsTableView.isHidden = viewModel.pickCard != nil
            rootView.sectionLabel.isHidden = viewModel.pickCard == nil
            let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
            rootView.setSection(strings.stakingSubtensorQuickRootSection())
            rootView.pickCardView.isHidden = viewModel.pickCard == nil

            applyAvgBuyPrice(.hidden)
            rootView.applyRootValidator(viewModel.validator)
            if let pickCard = viewModel.pickCard {
                rootView.pickCardView.bind(viewModel: pickCard)
                rootView.browseView.isHidden = true
            }
            rootView.applyNetworkFee(viewModel.networkFee)
        case let .subnet(viewModel):
            rootView.detailsTableView.isHidden = true
            rootView.sectionLabel.isHidden = false
            rootView.pickCardView.isHidden = false

            rootView.setSection(viewModel.sectionTitle)
            rootView.pickCardView.bind(viewModel: viewModel.card)

            applyAvgBuyPrice(viewModel.avgBuyPrice)
        }
    }

    func applyAvgBuyPrice(_ viewModel: SubtensorRowState<SubtensorCostBasisValueViewModel>) {
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

    @objc func actionBrowse() { presenter.showAllSubnets() }

    @objc func actionRetry() { presenter.retry() }

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

        rootView.setReserveWarning(viewModel.reserveWarning)
        rootView.setFailure(viewModel.failure)

        rootView.browseView.bind(title: viewModel.browseTitle)
        if case .subnet = viewModel.details {
            rootView.browseView.isHidden = true
        }
        applyDetails(viewModel.details)

        rootView.applyCaption(viewModel.caption)

        rootView.applyAction(viewModel.action)
    }

    func didStartLoading() {
        rootView.startLoading()
    }

    func didStopLoading() {
        rootView.stopLoading()
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
