import UIKit
import SoraUI

final class DAppURLBarView: ControlView<RoundedView, IconDetailsView> {
    init() {
        let titleView = IconDetailsView()
        titleView.mode = .iconDetails
        titleView.detailsLabel.numberOfLines = 0
        titleView.iconWidth = 12.0
        titleView.spacing = 5.0
        titleView.detailsLabel.textColor = R.color.colorWhite()
        titleView.detailsLabel.font = .regularFootnote

        let backgroundView = RoundedView()
        backgroundView.applyFilledBackgroundStyle()
        backgroundView.fillColor = R.color.colorWhite8()!
        backgroundView.highlightedFillColor = R.color.colorAccentSelected()!

        super.init(backgroundView: backgroundView, contentView: titleView, preferredHeight: 36.0)

        contentInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
    }

    override var intrinsicContentSize: CGSize {
        let width = UIView.layoutFittingExpandedSize.width

        return CGSize(width: width, height: preferredHeight ?? UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let contentWidth = controlContentView.detailsLabel.intrinsicContentSize.width +
            controlContentView.imageView.intrinsicContentSize.width + controlContentView.spacing

        let currentFrame = controlContentView.frame

        if contentWidth < currentFrame.width {
            controlContentView.frame = CGRect(
                x: bounds.midX - contentWidth / 2.0,
                y: currentFrame.origin.y,
                width: contentWidth,
                height: currentFrame.height
            )
        }
    }
}
