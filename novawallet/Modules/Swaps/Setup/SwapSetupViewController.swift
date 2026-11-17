import UIKit
import Foundation_iOS

final class SwapSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapSetupViewLayout

    let presenter: SwapSetupPresenterProtocol
    let chartViewProvider: AssetPriceChartCompactProviderProtocol
    let placement: SwapSetupPlacement

    var keyboardHandler: KeyboardHandler?
    var chartViewModel: SwapPriceChartViewModel?
    var isKeyboardVisible = false
    var isChartCollapseRequestedByDetails = false
    var isDetailsCardSettledHidden = true
    var isOnScreen = false
    var isFrontmostRequested = false
    var frontmostCheckTimer: Timer?

    var quoteState: SwapSetupQuoteState = .idle
    var isDetailsAvailable = false
    var hasRate = false
    var pendingFocus: TextFieldFocus?

    private var detailsAnimationGeneration = 0

    init(
        presenter: SwapSetupPresenterProtocol,
        chartViewProvider: AssetPriceChartCompactProviderProtocol,
        placement: SwapSetupPlacement,
        localizationManager: LocalizationManager
    ) {
        self.presenter = presenter
        self.chartViewProvider = chartViewProvider
        self.placement = placement
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwapSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupPlacement()
        setupHandlers()
        setupLocalization()
        setupPriceChart()
        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardHandler()
        keyboardHandler?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        isOnScreen = true
        applyPendingFocus()
        presenter.didChangeChartVisibility()
        updateFrontmostCheck()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        isOnScreen = false
        updateFrontmostCheck()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }
}

// MARK: Private

private extension SwapSetupViewController {
    func setupPlacement() {
        switch placement {
        case .swapsTab:
            rootView.setupTabHeader()
        case .flow:
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: R.image.iconSettings(),
                style: .plain,
                target: self,
                action: #selector(settingsAction)
            )
        }
    }

    func setupHandlers() {
        let targets: [(UIControl, Selector, UIControl.Event)] = [
            (rootView.payAmountInputView.assetControl, #selector(selectPayTokenAction), .touchUpInside),
            (rootView.payHeaderView.maxButton, #selector(payMaxAction), .touchUpInside),
            (rootView.payHeaderView.actionButton, #selector(depositTokenAction), .touchUpInside),
            (rootView.receiveAmountInputView.assetControl, #selector(selectReceiveTokenAction), .touchUpInside),
            (rootView.actionButton, #selector(continueAction), .touchUpInside),
            (rootView.switchButton, #selector(swapAction), .touchUpInside),
            (rootView.payAmountInputView.textInputView, #selector(payAmountChangeAction), .editingChanged),
            (rootView.receiveAmountInputView.textInputView, #selector(receiveAmountChangeAction), .editingChanged),
            (rootView.rateButton, #selector(rateInfoAction), .touchUpInside),
            (rootView.detailsView.rateCell, #selector(rateInfoAction), .touchUpInside),
            (rootView.detailsView.routeCell, #selector(routeDetailsAction), .touchUpInside),
            (rootView.detailsView.networkFeeCell, #selector(networkFeeInfoAction), .touchUpInside),
            (rootView.detailsView.priceDifferenceCell, #selector(priceDifferenceInfoAction), .touchUpInside),
            (rootView.detailsView.slippageCell, #selector(settingsAction), .touchUpInside),
            (rootView.detailsView.titleControl, #selector(detailsExpansionAction), .valueChanged),
            (rootView.depositTokenButton, #selector(depositTokenAction), .touchUpInside),
            (rootView.tabSettingsButton, #selector(settingsAction), .touchUpInside)
        ]

        targets.forEach { control, selector, event in
            control.addTarget(self, action: selector, for: event)
        }
    }

    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        title = strings.commonSwapTitle()
        rootView.tabTitleLabel.text = strings.tabbarSwapsTitle()

        let detailsView = rootView.detailsView
        detailsView.titleControl.titleLabel.text = strings.swapsSetupDetailsTitle()
        detailsView.rateCell.titleButton.imageWithTitleView?.title = strings.swapsSetupDetailsRate()
        detailsView.routeCell.titleButton.imageWithTitleView?.title = strings.swapsDetailsRoute()
        detailsView.execTimeCell.titleButton.imageWithTitleView?.title = strings.swapsDetailsExecTime()
        detailsView.networkFeeCell.titleButton.imageWithTitleView?.title = strings.swapsDetailsTotalFee()
        detailsView.priceDifferenceCell.titleButton.imageWithTitleView?.title = strings.swapsSetupPriceDifference()
        detailsView.slippageCell.titleButton.imageWithTitleView?.title = strings.swapsSetupSlippage()
        detailsView.minReceivedCell.titleButton.imageWithTitleView?.title = strings.swapsSetupDetailsMinReceived()

        [
            detailsView.rateCell.titleButton,
            detailsView.routeCell.titleButton,
            detailsView.execTimeCell.titleButton,
            detailsView.networkFeeCell.titleButton,
            detailsView.priceDifferenceCell.titleButton,
            detailsView.slippageCell.titleButton,
            detailsView.minReceivedCell.titleButton
        ].forEach { $0.invalidateLayout() }

        detailsView.titleControl.invalidateLayout()

        setupAccessoryView()
    }

    func setupAccessoryView() {
        let accessoryView = UIFactory.default.createDoneAccessoryView(
            target: self,
            selector: #selector(doneAction),
            locale: selectedLocale
        )
        rootView.payAmountInputView.textInputView.textField.inputAccessoryView = accessoryView
        rootView.receiveAmountInputView.textInputView.textField.inputAccessoryView = accessoryView
    }

    @objc func selectPayTokenAction() {
        view.endEditing(true)
        presenter.selectPayToken()
    }

    @objc func selectReceiveTokenAction() {
        view.endEditing(true)
        presenter.selectReceiveToken()
    }

    @objc func continueAction() {
        presenter.proceed()
    }

    @objc func swapAction() {
        let currentFocus: TextFieldFocus? = if rootView.payAmountInputView.isAmountFocused {
            .payAsset
        } else if rootView.receiveAmountInputView.isAmountFocused {
            .receiveAsset
        } else {
            nil
        }

        view.endEditing(true)
        presenter.flip(currentFocus: currentFocus)
    }

    @objc func payAmountChangeAction() {
        let amount = rootView.payAmountInputView.textInputView.inputViewModel?.decimalAmount
        presenter.updatePayAmount(amount)
    }

    @objc func receiveAmountChangeAction() {
        let amount = rootView.receiveAmountInputView.textInputView.inputViewModel?.decimalAmount
        presenter.updateReceiveAmount(amount)
    }

    @objc func networkFeeInfoAction() {
        presenter.showFeeInfo()
    }

    @objc func rateInfoAction() {
        presenter.showRateInfo()
    }

    @objc func routeDetailsAction() {
        presenter.showRouteDetails()
    }

    @objc func priceDifferenceInfoAction() {
        presenter.showPriceDifferenceInfo()
    }

    @objc func payMaxAction() {
        presenter.selectMaxPayAmount()
    }

    @objc func doneAction() {
        view.endEditing(true)
    }

    @objc func settingsAction() {
        view.endEditing(true)
        presenter.showSettings()
    }

    @objc func depositTokenAction() {
        presenter.depositInsufficientToken()
    }

    @objc func detailsExpansionAction() {
        detailsAnimationGeneration += 1

        let isExpanding = rootView.detailsView.expanded
        isChartCollapseRequestedByDetails = isExpanding

        let steps = isExpanding ? detailsExpansionSteps() : detailsCollapseSteps()

        runDetailsAnimation(steps[...], generation: detailsAnimationGeneration)
    }

    func detailsExpansionSteps() -> [DetailsAnimationStep] {
        let revealDetails = {
            guard self.isChartCollapsedByDetails else {
                return
            }

            self.rootView.scrollDetailsIntoView()
        }

        guard rootView.isRateVisible else {
            rootView.setRateFaded(true)
            return [applyDetailsLayout, revealDetails]
        }

        let hideRate = {
            self.rootView.setRateFaded(true)
        }

        return [hideRate, applyDetailsLayout, revealDetails]
    }

    func detailsCollapseSteps() -> [DetailsAnimationStep] {
        let revealRate = {
            self.rootView.setRateFaded(false)
        }

        return [applyDetailsLayout, revealRate]
    }

    func runDetailsAnimation(_ steps: ArraySlice<DetailsAnimationStep>, generation: Int) {
        guard let step = steps.first else {
            presenter.didChangeChartVisibility()
            return
        }

        UIView.animate(
            withDuration: Constants.detailsAnimationDuration,
            delay: 0,
            options: .beginFromCurrentState,
            animations: step,
            completion: { _ in
                guard generation == self.detailsAnimationGeneration else {
                    return
                }

                self.runDetailsAnimation(steps.dropFirst(), generation: generation)
            }
        )
    }

    func applyDetailsLayout() {
        rootView.detailsView.applyExpansion()
        updateDetailsVisibility()
        updateChartExpansion(animated: true)
        rootView.layoutIfNeeded()

        if !rootView.detailsView.expanded, isChartShownExpanded {
            rootView.scrollToContentTop()
        }
    }
}

extension SwapSetupViewController {
    typealias DetailsAnimationStep = () -> Void

    enum Constants {
        static let detailsAnimationDuration: TimeInterval = 0.25
        static let frontmostCheckInterval: TimeInterval = 0.2
    }
}

// MARK: Localizable

extension SwapSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
