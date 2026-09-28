import Foundation
import Foundation_iOS
import UIKit

final class SubtensorUnstakeSetupVC: CollatorStkBaseUnstakeSetupVC<SubtensorUnstakeSetupLayout> {
    var presenter: SubtensorUnstakeSetupPresenterProtocol? {
        basePresenter as? SubtensorUnstakeSetupPresenterProtocol
    }

    private var isUnstakeUnavailable: Bool = false
    private let isRootFlow: Bool

    init(
        presenter: SubtensorUnstakeSetupPresenterProtocol,
        isRootFlow: Bool,
        statics: CollatorStakingDelegateStatics,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.isRootFlow = isRootFlow
        super.init(
            basePresenter: presenter,
            statics: statics,
            localizationManager: localizationManager
        )
    }

    override func onViewDidLoad() {
        super.onViewDidLoad()

        rootView.quoteTableView.isHidden = true
        rootView.receiveCell.isHidden = true
        rootView.poolFeeCell.isHidden = true
        rootView.priceImpactCell.isHidden = true
        rootView.slippageCell.isHidden = true

        setupHandlers()
    }

    override func onSetupLocalization() {
        super.onSetupLocalization()

        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        title = isRootFlow ? strings.stakingSubtensorUiUnstakeFromRoot() : strings.stakingSubtensorUiSellSubnetTokens()
        rootView.amountView.titleView.text = isRootFlow
            ? strings.stakingSubtensorUiYouUnstake() : strings.stakingSubtensorUiYouSell()

        rootView.receiveCell.titleLabel.text = strings.stakingSubtensorQuoteReceiveTitle()
        rootView.poolFeeCell.titleLabel.text = strings.stakingSubtensorQuotePoolFeeTitle()
        rootView.priceImpactCell.titleLabel.text = strings.stakingSubtensorQuotePriceImpactTitle()
        rootView.slippageCell.titleLabel.text = strings.swapsSetupSlippage()

        // the amount row caps at what the chain lets the user move, not at the whole position
        rootView.amountView.detailsTitleLabel.text = strings.stakingSubtensorUnstakeAvailableTitle()

        setupAmountInputAccessoryView()
    }

    override func updateActionButtonState() {
        guard isUnstakeUnavailable else {
            super.updateActionButtonState()
            return
        }

        rootView.actionButton.applyDisabledStyle()
        rootView.actionButton.isUserInteractionEnabled = false

        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorUnstakeNothingAvailableTitle()

        rootView.actionButton.invalidateLayout()
    }
}

private extension SubtensorUnstakeSetupVC {
    func setupAmountInputAccessoryView() {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: selectedLocale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    func setupHandlers() {
        let amountChangeAction = UIAction { [weak self] _ in
            guard let self else {
                return
            }

            let amount = rootView.amountInputView.inputViewModel?.decimalAmount
            presenter?.updateAmount(amount)

            updateActionButtonState()
        }

        rootView.amountInputView.addAction(amountChangeAction, for: .editingChanged)

        let slippageAction = UIAction { [weak self] _ in
            self?.presenter?.selectSlippage()
        }

        rootView.slippageCell.addAction(slippageAction, for: .touchUpInside)
    }
}

extension SubtensorUnstakeSetupVC: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter?.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension SubtensorUnstakeSetupVC: SubtensorUnstakeSetupViewProtocol {
    func didReceiveQuote(viewModel: SubtensorQuotePanelViewModel?) {
        let hasQuote = viewModel != nil

        rootView.receiveCell.isHidden = !hasQuote
        rootView.poolFeeCell.isHidden = !hasQuote
        rootView.priceImpactCell.isHidden = !hasQuote

        updateQuotePanelVisibility()

        guard let viewModel else {
            return
        }

        rootView.receiveCell.bind(details: viewModel.receive)
        rootView.poolFeeCell.bind(details: viewModel.poolFee)
        rootView.priceImpactCell.bind(details: viewModel.priceImpact)

        rootView.priceImpactCell.detailsLabel.textColor = viewModel.isImpactHigh
            ? R.color.colorTextNegative()
            : R.color.colorTextPrimary()
    }

    func didReceiveSlippage(viewModel: String?) {
        rootView.slippageCell.isHidden = viewModel == nil
        rootView.slippageCell.bind(details: viewModel ?? "")

        updateQuotePanelVisibility()
    }

    func didReceiveUnstakeUnavailable(_ isUnavailable: Bool) {
        rootView.amountInputView.isUserInteractionEnabled = !isUnavailable

        isUnstakeUnavailable = isUnavailable

        updateActionButtonState()
    }
}

private extension SubtensorUnstakeSetupVC {
    func updateQuotePanelVisibility() {
        rootView.quoteTableView.isHidden = rootView.receiveCell.isHidden &&
            rootView.slippageCell.isHidden
    }
}
