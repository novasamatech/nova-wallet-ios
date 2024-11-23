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

    func setup(locale: Locale) {
        detailsView.titleControl.titleLabel.text = R.string.localizable.swapsSetupDetailsTitle(
            preferredLanguages: locale.rLanguages
        )

        slippageCell.titleButton.setTitle(
            R.string.localizable.swapsSetupSlippage(
                preferredLanguages: locale.rLanguages
            )
        )
        priceDifferenceCell.titleButton.setTitle(
            R.string.localizable.swapsSetupPriceDifference(
                preferredLanguages: locale.rLanguages
            )
        )
        rateCell.titleButton.setTitle(
            R.string.localizable.swapsSetupDetailsRate(
                preferredLanguages: locale.rLanguages
            )
        )
        routeCell.titleButton.setTitle(
            R.string.localizable.swapsDetailsRoute(preferredLanguages: locale.rLanguages)
        )

        totalFeeCell.titleButton.setTitle(
            R.string.localizable.swapsDetailsTotalFee(preferredLanguages: locale.rLanguages)
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
}
