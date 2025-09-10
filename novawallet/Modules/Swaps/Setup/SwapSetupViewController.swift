import UIKit
import Foundation_iOS

final class SwapSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapSetupViewLayout

    let presenter: SwapSetupPresenterProtocol

    private var toggledDetailsManually: Bool = false

    init(
        presenter: SwapSetupPresenterProtocol,
        localizationManager: LocalizationManager
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
        view = SwapSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        setupNavigationItem()
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.payAmountInputView.assetControl.addTarget(
            self,
            action: #selector(selectPayTokenAction),
            for: .touchUpInside
        )
        rootView.payAmountView.button.addTarget(
            self,
            action: #selector(payMaxAction),
            for: .touchUpInside
        )
        rootView.receiveAmountInputView.assetControl.addTarget(
            self,
            action: #selector(selectReceiveTokenAction),
            for: .touchUpInside
        )
        rootView.actionButton.addTarget(
            self,
            action: #selector(continueAction),
            for: .touchUpInside
        )
        rootView.switchButton.addTarget(
            self,
            action: #selector(swapAction),
            for: .touchUpInside
        )
        rootView.payAmountInputView.textInputView.addTarget(
            self,
            action: #selector(payAmountChangeAction),
            for: .editingChanged
        )
        rootView.receiveAmountInputView.textInputView.addTarget(
            self,
            action: #selector(receiveAmountChangeAction),
            for: .editingChanged
        )
        rootView.rateCell.addTarget(
            self,
            action: #selector(rateInfoAction),
            for: .touchUpInside
        )
        rootView.routeCell.addTarget(
            self,
            action: #selector(routeDetailsAction),
            for: .touchUpInside
        )
        rootView.networkFeeCell.addTarget(
            self,
            action: #selector(networkFeeInfoAction),
            for: .touchUpInside
        )
        rootView.depositTokenButton.addTarget(
            self,
            action: #selector(depositTokenAction),
            for: .touchUpInside
        )

        rootView.detailsView.delegate = self
    }

    private func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSwapTitle()
        rootView.setup(locale: selectedLocale)
        setupAccessoryView()
    }

    private func setupAccessoryView() {
        let accessoryView =
            UIFactory.default.createDoneAccessoryView(
                target: self,
                selector: #selector(doneAction),
                locale: selectedLocale
            )
        rootView.payAmountInputView.textInputView.textField.inputAccessoryView = accessoryView
        rootView.receiveAmountInputView.textInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupNavigationItem() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: R.image.iconOptions(),
            style: .plain,
            target: self,
            action: #selector(settingsAction)
        )
    }

    @objc private func selectPayTokenAction() {
        rootView.receiveAmountInputView.endEditing(true)
        presenter.selectPayToken()
    }

    @objc private func selectReceiveTokenAction() {
        rootView.payAmountInputView.endEditing(true)
        presenter.selectReceiveToken()
    }

    @objc private func continueAction() {
        presenter.proceed()
    }

    @objc private func swapAction() {
        let currentFocus: TextFieldFocus?
        if rootView.payAmountInputView.textInputView.textField.isFirstResponder {
            currentFocus = .payAsset
        } else if rootView.receiveAmountInputView.textInputView.textField.isFirstResponder {
            currentFocus = .receiveAsset
        } else {
            currentFocus = nil
        }
        view.endEditing(true)
        presenter.flip(currentFocus: currentFocus)
    }

    @objc private func payAmountChangeAction() {
        let amount = rootView.payAmountInputView.textInputView.inputViewModel?.decimalAmount
        presenter.updatePayAmount(amount)
    }

    @objc private func receiveAmountChangeAction() {
        let amount = rootView.receiveAmountInputView.textInputView.inputViewModel?.decimalAmount
        presenter.updateReceiveAmount(amount)
    }

    @objc private func networkFeeInfoAction() {
        presenter.showFeeInfo()
    }

    @objc private func rateInfoAction() {
        presenter.showRateInfo()
    }

    @objc private func routeDetailsAction() {
        presenter.showRouteDetails()
    }

    @objc private func payMaxAction() {
        presenter.selectMaxPayAmount()
    }

    @objc private func doneAction() {
        view.endEditing(true)
    }

    @objc private func settingsAction() {
        presenter.showSettings()
    }

    @objc private func depositTokenAction() {
        presenter.depositInsufficientToken()
    }
}

extension SwapSetupViewController: SwapSetupViewProtocol {
    func didReceiveButtonState(title: String, enabled: Bool) {
        rootView.actionButton.applyState(title: title, enabled: enabled)
    }

    func didReceiveTitle(payViewModel viewModel: TitleHorizontalMultiValueView.Model) {
        rootView.payAmountView.bind(model: viewModel)
    }

    func didReceiveInputChainAsset(payViewModel viewModel: SwapAssetInputViewModel) {
        switch viewModel {
        case let .asset(assetViewModel):
            rootView.payAmountInputView.bind(assetViewModel: assetViewModel)
            rootView.depositTokenButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.swapsSetupDepositButtonTitle(assetViewModel.symbol)
        case let .empty(emptySwapsAssetViewModel):
            rootView.payAmountInputView.bind(emptyViewModel: emptySwapsAssetViewModel)
            rootView.depositTokenButton.imageWithTitleView?.title = nil
        }
    }

    func didReceiveAmount(payInputViewModel inputViewModel: AmountInputViewModelProtocol) {
        rootView.payAmountInputView.bind(inputViewModel: inputViewModel)
    }

    func didReceiveAmountInputPrice(payViewModel viewModel: String?) {
        rootView.payAmountInputView.bind(priceViewModel: viewModel)
    }

    func didReceiveTitle(receiveViewModel viewModel: TitleHorizontalMultiValueView.Model) {
        rootView.receiveAmountView.bind(model: viewModel)
    }

    func didReceiveInputChainAsset(receiveViewModel viewModel: SwapAssetInputViewModel) {
        switch viewModel {
        case let .asset(swapsAssetViewModel):
            rootView.receiveAmountInputView.bind(assetViewModel: swapsAssetViewModel)
        case let .empty(emptySwapsAssetViewModel):
            rootView.receiveAmountInputView.bind(emptyViewModel: emptySwapsAssetViewModel)
        }
    }

    func didReceiveAmount(receiveInputViewModel inputViewModel: AmountInputViewModelProtocol) {
        rootView.receiveAmountInputView.bind(inputViewModel: inputViewModel)
    }

    func didReceiveAmountInputPrice(receiveViewModel viewModel: SwapPriceDifferenceViewModel?) {
        rootView.receiveAmountInputView.bind(priceDifferenceViewModel: viewModel)
    }

    func didReceiveDetailsState(isAvailable: Bool) {
        rootView.detailsView.isHidden = !isAvailable

        if !isAvailable {
            toggledDetailsManually = false
        }
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

    func didReceiveNetworkFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        rootView.networkFeeCell.bind(loadableViewModel: viewModel)

        if !toggledDetailsManually, !rootView.detailsView.expanded {
            rootView.detailsView.setExpanded(true, animated: true)
        }
    }

    func didReceiveSettingsState(isAvailable: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = isAvailable
    }

    func didReceive(focus: TextFieldFocus?) {
        switch focus {
        case .none:
            rootView.payAmountInputView.set(focused: false)
            rootView.receiveAmountInputView.set(focused: false)
        case .payAsset:
            rootView.payAmountInputView.set(focused: true)
        case .receiveAsset:
            rootView.receiveAmountInputView.set(focused: true)
        }
    }

    func didReceive(issues: [SwapSetupViewIssue]) {
        rootView.hideIssues()
        rootView.changeDepositTokenButtonVisibility(hidden: true)

        issues.forEach { issue in
            switch issue {
            case .zeroBalance:
                rootView.changeDepositTokenButtonVisibility(hidden: false)
            case .zeroReceiveAmount:
                let message = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonPositiveAmount()

                rootView.displayReceiveIssue(with: message)
            case .insufficientBalance:
                rootView.changeDepositTokenButtonVisibility(hidden: false)

                let message = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.swapsNotEnoughTokens()

                rootView.displayPayIssue(with: message)
            case let .minBalanceViolation(minBalance):
                let message = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonReceiveAtLeastEdError(minBalance)

                rootView.displayReceiveIssue(with: message)
            case .noLiqudity:
                let message = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.swapsNotEnoughLiquidity()

                rootView.displayPayIssue(with: message)
            }
        }
    }

    func didStartLoading() {
        rootView.loadableActionView.startLoading()
    }

    func didStopLoading() {
        rootView.loadableActionView.stopLoading()
    }
}

extension SwapSetupViewController: CollapsableContainerViewDelegate {
    func animateAlongsideWithInfo(sender _: AnyObject?) {
        rootView.containerView.scrollView.layoutIfNeeded()
    }

    func didChangeExpansion(isExpanded _: Bool, sender _: AnyObject) {
        toggledDetailsManually = true
    }
}

extension SwapSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
