import UIKit

final class NetworkTracksContainerView: UIView {
    let titleLabel: UILabel = .create {
        $0.apply(style: .boldTitle3Primary)
    }

    let networkView = AssetListChainView()

    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 7

    private var calculatedIntrinsicSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(titleLabel)
        addSubview(networkView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        calculatedIntrinsicSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let labelSize = titleLabel.intrinsicContentSize
        let networkViewSize = networkView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)

        let totalOneLineWidth = labelSize.width + horizontalSpacing +
            networkViewSize.width

        titleLabel.frame = CGRect(
            origin: .init(x: bounds.minX, y: bounds.minY),
            size: labelSize
        )

        let intrinsicHeight: CGFloat

        if totalOneLineWidth <= bounds.width {
            networkView.frame = CGRect(
                x: titleLabel.frame.maxX + horizontalSpacing,
                y: titleLabel.frame.midY - networkViewSize.height / 2.0,
                width: networkViewSize.width,
                height: networkViewSize.height
            )

            intrinsicHeight = max(labelSize.height, networkViewSize.height)
        } else {
            networkView.frame = CGRect(
                x: titleLabel.frame.minX + horizontalSpacing,
                y: titleLabel.frame.maxY + verticalSpacing,
                width: networkViewSize.width,
                height: networkViewSize.height
            )

            intrinsicHeight = labelSize.height + verticalSpacing + networkViewSize.height
        }

        if abs(calculatedIntrinsicSize.width - bounds.width) > CGFloat.leastNormalMagnitude ||
            abs(calculatedIntrinsicSize.height - intrinsicHeight) > CGFloat.leastNormalMagnitude {
            calculatedIntrinsicSize = CGSize(width: bounds.width, height: intrinsicHeight)
            invalidateIntrinsicContentSize()
        }
    }
}
