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

    private var actionButton: TriangularedButton?

    func setupDoneButton(for locale: Locale) -> TriangularedButton {
        setupActionButton(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonDone()
        )
    }

    func setupTryAgainButton(for locale: Locale) -> TriangularedButton {
        setupActionButton(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonTryAgain()
        )
    }

    func setFinished() {
        closeButton.isHidden = false
        stackView.layoutMargins.top = Constants.finishedTopInset
    }

    func setup(locale: Locale) {
        detailsView.setup(locale: locale)
    }

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    override func setupLayout() {
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

        addSubview(actionsView)
        actionsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}

private extension SwapExecutionViewLayout {
    func setupActionButton(title: String) -> TriangularedButton {
        actionButton?.removeFromSuperview()

        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.setTitle(title)

        actionsView.addArrangedSubview(button)

        actionButton = button

        containerView.scrollBottomOffset = safeAreaInsets.bottom + UIConstants.actionBottomInset +
            UIConstants.actionHeight + Constants.sectionSpacing

        return button
    }
}

extension SwapExecutionViewLayout {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 28, left: 16, bottom: 0, right: 16)
        static let finishedTopInset: CGFloat = 60
        static let statusSpacing: CGFloat = 16
        static let sectionSpacing: CGFloat = 12
        static let closeTopInset: CGFloat = 7
        static let closeSize: CGFloat = 44
        static let actionsSpacing: CGFloat = 12
    }
}
