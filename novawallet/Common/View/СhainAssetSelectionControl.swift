import Foundation
import SoraUI

final class ChainAssetSelectionControl: DetailsTriangularedView {
    let iconBackgroundView: RoundedView = {
        let view = RoundedView()
        view.cornerRadius = 20.0
        view.shadowOpacity = 0.0
        return view
    }()

    var iconBackgroundRadius: CGFloat {
        get {
            iconBackgroundView.cornerRadius
        }

        set {
            iconBackgroundView.cornerRadius = newValue

            setNeedsLayout()
        }
    }

    var titleAdditionalTopMargin: CGFloat = 2.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var subtitleAdditionalBottomMargin: CGFloat = 2.0 {
        didSet {
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        layout = .largeIconTitleSubtitle

        contentView?.insertSubview(iconBackgroundView, belowSubview: iconView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let size = 2 * iconBackgroundView.cornerRadius
        iconBackgroundView.frame = CGRect(
            x: iconView.frame.midX - size / 2.0,
            y: iconView.frame.midY - size / 2.0,
            width: size,
            height: size
        )

        var titleFrame = titleLabel.frame
        titleFrame.origin = CGPoint(
            x: titleFrame.origin.x,
            y: titleFrame.origin.y + titleAdditionalTopMargin
        )

        titleLabel.frame = titleFrame

        if let subtitleLabel = subtitleLabel {
            var subtitleFrame = subtitleLabel.frame
            subtitleFrame.origin = CGPoint(
                x: subtitleFrame.origin.x,
                y: subtitleFrame.origin.y - subtitleAdditionalBottomMargin
            )

            subtitleLabel.frame = subtitleFrame
        }
    }
}
