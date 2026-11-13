import UIKit
import UIKit_iOS

final class SwapSetupViewLayout: ScrollableContainerLayoutView {
    let backgroundView = MultigradientView.background

    let tabHeaderView = UIView()

    let tabTitleLabel: UILabel = .create {
        $0.apply(style: .boldTitle1Primary)
    }

    let tabSettingsButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.roundedBackgroundView?.fillColor = R.color.colorChipsBackground()!
        $0.roundedBackgroundView?.highlightedFillColor = R.color.colorChipsBackground()!
        $0.roundedBackgroundView?.cornerRadius = Constants.tabButtonSize / 2
        $0.imageWithTitleView?.iconImage = R.image.iconSettings()
    }

    let chartContainerView: UIView = .create {
        $0.backgroundColor = R.color.colorBlockBackground()
        $0.layer.cornerRadius = Constants.chartCollapsedCornerRadius
        $0.clipsToBounds = true
    }

    let payHeaderView = SwapSetupAssetHeaderView()

    let payAmountInputView = SwapAmountInputView()

    let payIssueLabel: UILabel = .create {
        $0.apply(style: .caption1Negative)
        $0.numberOfLines = 0
    }

    private lazy var payIssueContainer = createIssueContainer(for: payIssueLabel)

    let depositTokenButton: TriangularedButton = .create {
        $0.applySecondaryDefaultStyle()
        $0.isHidden = true
    }

    let receiveHeaderView = SwapSetupAssetHeaderView()

    let receiveAmountInputView = SwapAmountInputView()

    let receiveIssueLabel: UILabel = .create {
        $0.apply(style: .caption1Negative)
        $0.numberOfLines = 0
    }

    private lazy var receiveIssueContainer = createIssueContainer(for: receiveIssueLabel)

    let switchButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.roundedBackgroundView?.fillColor = R.color.colorBlockBackground()!
        $0.roundedBackgroundView?.highlightedFillColor = R.color.colorBlockBackground()!
        $0.roundedBackgroundView?.cornerRadius = Constants.switchSize / 2
        $0.roundedBackgroundView?.layer.cornerRadius = Constants.switchSize / 2
        $0.roundedBackgroundView?.layer.borderWidth = Constants.switchBorderWidth
        $0.roundedBackgroundView?.layer.borderColor = R.color.colorSecondaryScreenBackground()!.cgColor
        $0.imageWithTitleView?.iconImage = R.image.iconActionSwap()
    }

    let rateButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.imageWithTitleView?.titleFont = .regularFootnote
        $0.imageWithTitleView?.titleColor = R.color.colorTextPrimary()
        $0.imageWithTitleView?.iconImage = R.image.iconInfoFilled()
        $0.imageWithTitleView?.layoutType = .horizontalLabelFirst
        $0.imageWithTitleView?.spacingBetweenLabelAndIcon = Constants.rateIconSpacing
        $0.contentInsets = .zero
    }

    let detailsView: SwapDetailsView = .create {
        $0.isHidden = true
    }

    private let rateContainerView: UIView = .create {
        $0.isHidden = true
    }

    let loadableActionView = LoadableActionView()

    var actionButton: TriangularedButton {
        loadableActionView.actionButton
    }

    private var commissionDisclosureView: UILabel?

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    override func setupLayout() {
        insertSubview(backgroundView, at: 0)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        super.setupLayout()

        stackView.layoutMargins = Constants.contentInsets
        stackView.insetsLayoutMarginsFromSafeArea = false

        addSubview(loadableActionView)
        loadableActionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        setupContentLayout()
        setupSwitchButtonLayout()
    }

    func setupTabHeader() {
        addSubview(tabHeaderView)
        tabHeaderView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.tabHeaderHeight)
        }

        tabHeaderView.addSubview(tabSettingsButton)
        tabSettingsButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(Constants.tabButtonTopInset)
            make.size.equalTo(Constants.tabButtonSize)
        }

        tabHeaderView.addSubview(tabTitleLabel)
        tabTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.lessThanOrEqualTo(tabSettingsButton.snp.leading).offset(-UIConstants.horizontalInset)
            make.centerY.equalTo(tabSettingsButton)
        }

        containerView.snp.remakeConstraints { make in
            make.top.equalTo(tabHeaderView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        stackView.layoutMargins.top = Constants.tabContentTopInset
    }

    func setCommissionDisclosure(_ text: String?) {
        applyCaption(
            on: &commissionDisclosureView,
            after: detailsView,
            text: text
        )
    }

    func setChartHeight(_ height: CGFloat, isExpanded: Bool) {
        chartContainerView.snp.updateConstraints {
            $0.height.equalTo(height)
        }

        chartContainerView.layer.cornerRadius = isExpanded
            ? Constants.chartExpandedCornerRadius
            : Constants.chartCollapsedCornerRadius
    }

    func scrollDetailsIntoView() {
        let scrollView = containerView.scrollView
        let insets = scrollView.adjustedContentInset
        let offset = scrollView.contentOffset.y
        let detailsBottomView = commissionDisclosureView ?? detailsView

        let detailsTop = scrollView.convert(detailsView.bounds, from: detailsView).minY
        let detailsBottom = scrollView.convert(detailsBottomView.bounds, from: detailsBottomView).maxY
        let actionTop = scrollView.convert(loadableActionView.bounds, from: loadableActionView).minY

        let visibleTop = offset + insets.top
        let visibleBottom = min(
            offset + scrollView.bounds.height - insets.bottom,
            actionTop - Constants.detailsActionSpacing
        )

        let shift = min(detailsBottom - visibleBottom, detailsTop - visibleTop)

        guard shift > 0 else {
            return
        }

        let maxOffset = max(-insets.top, scrollView.contentSize.height + insets.bottom - scrollView.bounds.height)

        scrollView.contentOffset.y = min(offset + shift, maxOffset)
    }

    func scrollToContentTop() {
        let scrollView = containerView.scrollView
        scrollView.contentOffset.y = -scrollView.adjustedContentInset.top
    }

    var isRateVisible: Bool {
        !rateContainerView.isHidden
    }

    func setRateVisible(_ isVisible: Bool) {
        rateContainerView.isHidden = !isVisible

        updateReceiveSpacings()
    }

    func setRateFaded(_ isFaded: Bool) {
        rateContainerView.alpha = isFaded ? 0 : 1
    }

    func setDepositTokenButtonVisible(_ isVisible: Bool) {
        depositTokenButton.isHidden = !isVisible
    }

    func hideIssues() {
        displayPayIssue(with: nil)
        displayReceiveIssue(with: nil)
    }

    func displayPayIssue(with text: String?) {
        payIssueLabel.text = text
        payIssueContainer.isHidden = text == nil
        payAmountInputView.applyInput(style: text == nil ? .normal : .error)
    }

    func displayReceiveIssue(with text: String?) {
        receiveIssueLabel.text = text
        receiveIssueContainer.isHidden = text == nil
        receiveAmountInputView.applyInput(style: text == nil ? .normal : .error)

        updateReceiveSpacings()
    }
}

// MARK: Private

private extension SwapSetupViewLayout {
    func setupContentLayout() {
        addArrangedSubview(chartContainerView, spacingAfter: Constants.chartSpacingAfter)
        chartContainerView.snp.makeConstraints {
            $0.height.equalTo(0)
        }

        addArrangedSubview(payHeaderView, spacingAfter: Constants.headerSpacingAfter)
        addArrangedSubview(payAmountInputView, spacingAfter: Constants.cardSpacingAfter)
        addArrangedSubview(payIssueContainer, spacingAfter: Constants.issueSpacingAfter)
        addArrangedSubview(depositTokenButton, spacingAfter: Constants.depositSpacingAfter)
        depositTokenButton.snp.makeConstraints {
            $0.height.equalTo(Constants.depositHeight)
        }

        addArrangedSubview(receiveHeaderView, spacingAfter: Constants.headerSpacingAfter)
        addArrangedSubview(receiveAmountInputView, spacingAfter: Constants.receiveToRateSpacing)
        addArrangedSubview(receiveIssueContainer, spacingAfter: Constants.receiveToRateSpacing)

        rateContainerView.addSubview(rateButton)
        rateButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.rateHorizontalInset)
            make.top.bottom.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }

        addArrangedSubview(rateContainerView, spacingAfter: Constants.rateSpacingAfter)
        rateContainerView.snp.makeConstraints {
            $0.height.equalTo(Constants.rateTapHeight)
        }

        addArrangedSubview(detailsView, spacingAfter: Constants.commissionSpacing)

        updateReceiveSpacings()
    }

    func createIssueContainer(for label: UILabel) -> UIView {
        let container = UIView()
        container.isHidden = true
        container.addSubview(label)

        label.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(Constants.issueHorizontalInset)
        }

        return container
    }

    func updateReceiveSpacings() {
        let spacingAfterReceive = rateContainerView.isHidden
            ? Constants.receiveToDetailsSpacing
            : Constants.receiveToRateSpacing

        if receiveIssueContainer.isHidden {
            stackView.setCustomSpacing(spacingAfterReceive, after: receiveAmountInputView)
        } else {
            stackView.setCustomSpacing(Constants.receiveIssueSpacing, after: receiveAmountInputView)
            stackView.setCustomSpacing(spacingAfterReceive, after: receiveIssueContainer)
        }
    }

    func setupSwitchButtonLayout() {
        containerView.scrollView.addSubview(switchButton)
        let balanceView = receiveHeaderView.maxButton

        switchButton.snp.makeConstraints {
            $0.size.equalTo(Constants.switchSize)
            $0.bottom.equalTo(receiveAmountInputView.snp.top).offset(-Constants.switchReceiveSpacing)
            $0.centerX.equalTo(receiveHeaderView).priority(.medium)
            $0.trailing.lessThanOrEqualTo(balanceView.snp.leading).offset(-Constants.switchBalanceSpacing)
        }
    }
}

extension SwapSetupViewLayout {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 100, right: 16)
        static let tabHeaderHeight: CGFloat = 50
        static let tabButtonSize: CGFloat = 44
        static let tabButtonTopInset: CGFloat = 6
        static let tabContentTopInset: CGFloat = 10
        static let chartSpacingAfter: CGFloat = 10
        static let chartExpandedCornerRadius: CGFloat = 16
        static let chartCollapsedCornerRadius: CGFloat = 12
        static let headerSpacingAfter: CGFloat = 2
        static let cardSpacingAfter: CGFloat = 6
        static let issueSpacingAfter: CGFloat = 10
        static let issueHorizontalInset: CGFloat = 4
        static let depositSpacingAfter: CGFloat = 12
        static let depositHeight: CGFloat = 44
        static let receiveIssueSpacing: CGFloat = 6
        static let receiveToDetailsSpacing: CGFloat = 12
        static let rateHeight: CGFloat = 18
        static let rateTapHeight: CGFloat = 44
        static let rateTapOutset: CGFloat = (rateTapHeight - rateHeight) / 2
        static let receiveToRateSpacing: CGFloat = 14 - rateTapOutset
        static let rateHorizontalInset: CGFloat = 4
        static let rateIconSpacing: CGFloat = 16
        static let rateSpacingAfter: CGFloat = 16 - rateTapOutset
        static let commissionSpacing: CGFloat = 8
        static let detailsActionSpacing: CGFloat = 10
        static let switchSize: CGFloat = 36
        static let switchBorderWidth: CGFloat = 2
        static let switchReceiveSpacing: CGFloat = 2
        static let switchBalanceSpacing: CGFloat = 8
    }
}
