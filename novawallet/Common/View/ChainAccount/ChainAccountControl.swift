import Foundation
import SoraUI

final class ChainAccountControl: BackgroundedContentControl {
    let chainAccountView = ChainAccountView()
    let roundedBackgroundView: RoundedView = {
        let roundedView = UIFactory.default.createRoundedBackgroundView()
        roundedView.applyControlBackgroundStyle()
        return roundedView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentInsets = UIEdgeInsets(
            top: 7.0,
            left: 18.0,
            bottom: 7.0,
            right: 18.0
        )

        backgroundView = roundedBackgroundView
        contentView = chainAccountView
        contentView?.isUserInteractionEnabled = false
        backgroundView?.isUserInteractionEnabled = false

        contentView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundView?.frame = bounds

        contentView?.frame = CGRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY + contentInsets.top,
            width: bounds.width - contentInsets.left - contentInsets.right,
            height: bounds.height - contentInsets.top - contentInsets.bottom
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
