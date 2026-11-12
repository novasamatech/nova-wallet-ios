import UIKit
import Foundation_iOS

extension SwapSetupViewController {
    func updateDetailsVisibility() {
        let isQuoted = quoteState == .loaded
        let detailsVisible = isDetailsAvailable && isQuoted

        rootView.detailsView.isHidden = !detailsVisible
        rootView.setRateVisible(detailsVisible && hasRate && !rootView.detailsView.expanded)
    }

    func applyPendingFocus() {
        guard let focus = pendingFocus else {
            return
        }

        pendingFocus = nil
        apply(focus: focus)
    }

    func apply(focus: TextFieldFocus?) {
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

    func applyQuoteStateToInputs() {
        let payLoading: Bool
        let receiveLoading: Bool
        let payMasked: Bool
        let receiveMasked: Bool

        switch quoteState {
        case let .loading(direction), let .failed(direction):
            payLoading = direction == .buy
            receiveLoading = direction == .sell
            payMasked = false
            receiveMasked = false
        case let .noRoute(direction):
            payLoading = false
            receiveLoading = false
            payMasked = direction == .buy
            receiveMasked = direction == .sell
        case .idle, .loaded:
            payLoading = false
            receiveLoading = false
            payMasked = false
            receiveMasked = false
        }

        rootView.payAmountInputView.setLoading(payLoading)
        rootView.receiveAmountInputView.setLoading(receiveLoading)
        rootView.payAmountInputView.setValueMasked(payMasked)
        rootView.receiveAmountInputView.setValueMasked(receiveMasked)
    }

    func applyIssues(_ issues: [SwapSetupViewIssue]) {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        var payIssue: String?
        var receiveIssue: String?
        var showsDeposit = false
        var showsGetAction = false

        for issue in issues {
            switch issue {
            case .zeroBalance:
                showsGetAction = true
            case .zeroReceiveAmount:
                receiveIssue = strings.commonPositiveAmount()
            case .insufficientBalance:
                showsDeposit = true
                payIssue = strings.swapsNotEnoughTokens()
            case let .minBalanceViolation(minBalance):
                receiveIssue = strings.commonReceiveAtLeastEdError(minBalance)
            case .noLiqudity:
                break
            }
        }

        rootView.displayPayIssue(with: payIssue)
        rootView.displayReceiveIssue(with: receiveIssue)
        rootView.setDepositTokenButtonVisible(showsDeposit)
        rootView.payHeaderView.setActionVisible(showsGetAction && !showsDeposit)
    }
}

// MARK: SwapSetupViewProtocol

extension SwapSetupViewController: SwapSetupViewProtocol {
    func didReceiveButtonState(title: String, enabled: Bool) {
        rootView.actionButton.applyState(title: title, enabled: enabled)
    }

    func didReceiveTitle(payViewModel viewModel: TitleHorizontalMultiValueView.Model) {
        rootView.payHeaderView.bind(model: viewModel)
    }

    func didReceiveInputChainAsset(payViewModel viewModel: SwapAssetInputViewModel) {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        switch viewModel {
        case let .asset(assetViewModel):
            rootView.payAmountInputView.bind(assetViewModel: assetViewModel)

            let depositTitle = strings.swapsSetupDepositButtonTitle(assetViewModel.symbol)
            rootView.depositTokenButton.imageWithTitleView?.title = depositTitle
            rootView.payHeaderView.setAction(title: depositTitle, balanceTitle: strings.swapsSetupAssetBalance())
        case let .empty(emptySwapsAssetViewModel):
            rootView.payAmountInputView.bind(emptyViewModel: emptySwapsAssetViewModel)
            rootView.depositTokenButton.imageWithTitleView?.title = nil
            rootView.payHeaderView.setAction(title: nil, balanceTitle: strings.swapsSetupAssetBalance())
        }
    }

    func didReceiveAmount(payInputViewModel inputViewModel: AmountInputViewModelProtocol) {
        rootView.payAmountInputView.bind(inputViewModel: inputViewModel)
    }

    func didReceiveAmountInputPrice(payViewModel viewModel: String?) {
        rootView.payAmountInputView.bind(priceViewModel: viewModel)
    }

    func didReceiveTitle(receiveViewModel viewModel: TitleHorizontalMultiValueView.Model) {
        rootView.receiveHeaderView.bindBalance(model: viewModel)
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
        rootView.receiveAmountInputView.bind(priceViewModel: viewModel?.price)

        let detailsView = rootView.detailsView

        if let difference = viewModel?.difference {
            detailsView.priceDifferenceCell.bind(differenceViewModel: .loaded(value: difference))
            detailsView.setPriceDifferenceVisible(true)
        } else {
            detailsView.setPriceDifferenceVisible(false)
        }
    }

    func didReceiveDetailsState(isAvailable: Bool) {
        isDetailsAvailable = isAvailable

        updateDetailsVisibility()
    }

    func didReceiveRate(viewModel: LoadableViewModelState<String>) {
        rootView.detailsView.rateCell.bind(loadableViewModel: viewModel)

        switch viewModel {
        case let .loaded(value), let .cached(value):
            hasRate = true
            rootView.rateButton.imageWithTitleView?.title = value
            rootView.rateButton.invalidateLayout()
        case .loading:
            hasRate = false
        }

        updateDetailsVisibility()
    }

    func didReceiveRoute(viewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>) {
        rootView.detailsView.routeCell.bind(loadableRouteViewModel: viewModel)
    }

    func didReceiveExecutionTime(viewModel: LoadableViewModelState<String>) {
        rootView.detailsView.execTimeCell.bind(loadableViewModel: viewModel)
    }

    func didReceiveNetworkFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        rootView.detailsView.networkFeeCell.bind(loadableViewModel: viewModel)
    }

    func didReceiveCommissionDisclosure(viewModel: String?) {
        rootView.setCommissionDisclosure(viewModel)
    }

    func didReceiveSettingsState(isAvailable: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = isAvailable
        rootView.tabSettingsButton.isEnabled = isAvailable
    }

    func didReceiveSlippage(viewModel: SwapSetupSlippageViewModel) {
        let cell = rootView.detailsView.slippageCell
        cell.bind(loadableViewModel: .loaded(value: viewModel.value))
        cell.bind(attention: viewModel.hasWarning ? .medium : .low)
    }

    func didReceive(quoteState: SwapSetupQuoteState) {
        self.quoteState = quoteState

        applyQuoteStateToInputs()
        updateDetailsVisibility()
    }

    func didReceive(focus: TextFieldFocus?) {
        guard viewIfLoaded?.window != nil else {
            pendingFocus = focus
            return
        }

        apply(focus: focus)
    }

    func didReceive(issues: [SwapSetupViewIssue]) {
        applyIssues(issues)
    }

    func didStartLoading() {
        rootView.loadableActionView.startLoading()
    }

    func didStopLoading() {
        rootView.loadableActionView.stopLoading()
    }
}
