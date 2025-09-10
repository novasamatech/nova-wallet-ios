import UIKit

final class SwapExecutionViewLayout: ScrollableContainerLayoutView {
    let statusView = SwapExecutionView()

    let pairsView = SwapPairView()

    let detailsView: SwapExecutionDetailsView = .create {
        $0.contentInsets = .zero
        $0.setExpanded(false, animated: false)
    }

    var rateCell: SwapInfoViewCell {
        detailsView.rateCell
    }

    var routeCell: SwapRouteViewCell {
        detailsView.routeCell
    }

    var priceDifferenceCell: SwapInfoViewCell {
        detailsView.priceDifferenceCell
    }

    var slippageCell: SwapInfoViewCell {
        detailsView.slippageCell
    }

    var totalFeeCell: SwapNetworkFeeViewCell {
        detailsView.totalFeeCell
    }

    private var actionButton: TriangularedButton?

    func setupDoneButton(for locale: Locale) -> TriangularedButton {
        let button = setupActionButton()

        button.setTitle(R.string(preferredLanguages: locale.rLanguages).localizable.commonDone())

        containerView.scrollBottomOffset = safeAreaInsets.bottom + UIConstants.actionBottomInset +
            UIConstants.actionHeight + 8

        return button
    }

    func setupTryAgainButton(for locale: Locale) -> TriangularedButton {
        let button = setupActionButton()

        button.setTitle(R.string(preferredLanguages: locale.rLanguages).localizable.commonTryAgain())

        containerView.scrollBottomOffset = safeAreaInsets.bottom + UIConstants.actionBottomInset +
            UIConstants.actionHeight + 8

        return button
    }

    func setup(locale: Locale) {
        detailsView.titleControl.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupDetailsTitle()

        slippageCell.titleButton.setTitle(
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupSlippage()
        )
        priceDifferenceCell.titleButton.setTitle(
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupPriceDifference()
        )
        rateCell.titleButton.setTitle(
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupDetailsRate()
        )
        routeCell.titleButton.setTitle(
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsDetailsRoute()
        )

        totalFeeCell.titleButton.setTitle(
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsDetailsTotalFee()
        )
    }

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins = UIEdgeInsets(top: 76, left: 16, bottom: 0, right: 16)

        addArrangedSubview(statusView, spacingAfter: 24)
        addArrangedSubview(pairsView, spacingAfter: 24)
        addArrangedSubview(detailsView)
    }

    private func setupActionButton() -> TriangularedButton {
        actionButton?.removeFromSuperview()
        actionButton = nil

        let button = TriangularedButton()
        button.applyDefaultStyle()

        addSubview(button)

        addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        actionButton = button

        return button
    }
}
