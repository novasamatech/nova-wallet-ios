import UIKit
import UIKit_iOS

final class SwapExecutionViewLayout: ScrollableContainerLayoutView {
    let closeButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.imageWithTitleView?.iconImage = R.image.iconClose()?.tinted(with: R.color.colorIconPrimary()!)
        $0.roundedBackgroundView?.fillColor = R.color.colorChipsBackground()!
        $0.roundedBackgroundView?.highlightedFillColor = R.color.colorChipsBackground()!
        $0.roundedBackgroundView?.cornerRadius = SwapExecutionViewLayout.Constants.closeSize / 2
        $0.isHidden = true
    }

    let titleLabel: UILabel = .create {
        $0.apply(style: .semiboldBodyPrimary)
        $0.textAlignment = .center
    }

    let statusView = SwapExecutionView()

    let pairsView = SwapReviewPairView()

    let stepsView: SwapExecutionStepsView = .create {
        $0.isHidden = true
    }

    let detailsView = SwapExecutionDetailsView()

    var rateCell: SwapReviewTextCell {
        detailsView.rateCell
    }

    var routeCell: SwapReviewRouteCell {
        detailsView.routeCell
    }

    var totalFeeCell: SwapReviewTextCell {
        detailsView.totalFeeCell
    }

    let actionsView = UIView.hStack(
        distribution: .fillEqually,
        spacing: Constants.actionsSpacing,
        []
    )

    private var actionButtons: [TriangularedButton] = []

    func setupCompletedButtons(
        for locale: Locale,
        viewAssetTitle: String?
    ) -> (done: TriangularedButton, viewAsset: TriangularedButton?) {
        removeActionButtons()

        let viewAssetButton = viewAssetTitle.map { addActionButton(title: $0, isPrimary: false) }

        let doneButton = addActionButton(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonDone(),
            isPrimary: true
        )

        return (doneButton, viewAssetButton)
    }

    func setupTryAgainButton(for locale: Locale) -> TriangularedButton {
        removeActionButtons()

        return addActionButton(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonTryAgain(),
            isPrimary: true
        )
    }

    func setFinished(isSuccess: Bool) {
        closeButton.isHidden = false
        titleLabel.isHidden = true
        stackView.layoutMargins.top = isSuccess ? Constants.completedTopInset : Constants.failedTopInset
    }

    func setup(locale: Locale) {
        titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonSwapTitle()
        detailsView.setup(locale: locale)
    }

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    override func setupLayout() {
        insertSwapBackground()

        super.setupLayout()

        stackView.layoutMargins = Constants.contentInsets

        addArrangedSubview(statusView, spacingAfter: Constants.statusSpacing)
        addArrangedSubview(pairsView, spacingAfter: Constants.sectionSpacing)
        addArrangedSubview(stepsView, spacingAfter: Constants.sectionSpacing)
        addArrangedSubview(detailsView)

        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).inset(Constants.closeTopInset)
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(Constants.closeSize)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
            make.leading.greaterThanOrEqualTo(closeButton.snp.trailing)
        }

        addSubview(actionsView)
        actionsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}

private extension SwapExecutionViewLayout {
    func removeActionButtons() {
        actionButtons.forEach { $0.removeFromSuperview() }
        actionButtons = []
    }

    func addActionButton(title: String, isPrimary: Bool) -> TriangularedButton {
        let button = TriangularedButton()

        if isPrimary {
            button.applyDefaultStyle()
        } else {
            button.applySecondaryDefaultStyle()
        }

        button.setTitle(title)

        actionsView.addArrangedSubview(button)

        actionButtons.append(button)

        containerView.scrollBottomOffset = safeAreaInsets.bottom + UIConstants.actionBottomInset +
            UIConstants.actionHeight + Constants.sectionSpacing

        return button
    }
}

extension SwapExecutionViewLayout {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 65, left: 16, bottom: 0, right: 16)
        static let completedTopInset: CGFloat = 65
        static let failedTopInset: CGFloat = 57
        static let statusSpacing: CGFloat = 16
        static let sectionSpacing: CGFloat = 12
        static let closeTopInset: CGFloat = 7
        static let closeSize: CGFloat = 44
        static let actionsSpacing: CGFloat = 12
    }
}
