import UIKit
import SoraUI

final class DAppURLBarView: BackgroundedContentControl {
    let preferredHeight: CGFloat

    var controlContentView: IconDetailsView! { contentView as? IconDetailsView }

    var controlBackgroundView: RoundedView! { backgroundView as? RoundedView }

    init() {
        let titleView = IconDetailsView()
        titleView.mode = .iconDetails
        titleView.detailsLabel.numberOfLines = 1
        titleView.iconWidth = 12.0
        titleView.spacing = 5.0
        titleView.detailsLabel.textColor = R.color.colorWhite()
        titleView.detailsLabel.font = .regularFootnote
        titleView.isUserInteractionEnabled = false

        let backgroundView = RoundedView()
        backgroundView.applyFilledBackgroundStyle()
        backgroundView.fillColor = R.color.colorWhite8()!
        backgroundView.highlightedFillColor = R.color.colorAccentSelected()!
        backgroundView.isUserInteractionEnabled = false

        preferredHeight = 36.0

        super.init(frame: .zero)

        contentView = titleView
        self.backgroundView = backgroundView

        contentInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let width = UIView.layoutFittingExpandedSize.width

        return CGSize(width: width, height: preferredHeight)
    }

    override func layoutSubviews() {
        guard
            let contentView = contentView as? IconDetailsView,
            let backgroundView = backgroundView as? RoundedView else {
            return
        }

        let contentWidth: CGFloat = contentView.detailsLabel.intrinsicContentSize.width +
            contentView.imageView.intrinsicContentSize.width + contentView.spacing

        backgroundView.frame = bounds

        let width = min(max(bounds.width - contentInsets.left - contentInsets.right, 0), contentWidth)

        contentView.frame = CGRect(
            x: bounds.midX - width / 2.0,
            y: bounds.minY + contentInsets.top,
            width: width,
            height: bounds.height
        )
    }
}
