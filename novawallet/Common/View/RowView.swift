import UIKit
import SoraUI

class RowView<T: UIView>: BackgroundedContentControl {
    var preferredHeight: CGFloat? {
        didSet {
            invalidateLayout()
        }
    }

    let borderView = UIFactory.default.createBorderedContainerView()

    private var calculatedHeight: CGFloat = 0.0
    private var calculatedWidth: CGFloat = 0.0

    var rowContentView: T! { contentView as? T }

    var roundedBackgroundView: RoundedView! { backgroundView as? RoundedView }

    var hasInteractableContent: Bool = false {
        didSet {
            updateContentInteraction()
        }
    }

    init(contentView: T? = nil, preferredHeight: CGFloat? = nil) {
        self.preferredHeight = preferredHeight

        super.init(frame: .zero)

        self.contentView = contentView

        setupLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        let contentHeight: CGFloat

        let width = max(bounds.width - contentInsets.left - contentInsets.right, 0)

        if let preferredHeight = preferredHeight {
            contentHeight = preferredHeight - contentInsets.top - contentInsets.bottom
        } else {
            if abs(calculatedWidth - width) > CGFloat.leastNormalMagnitude {
                updateContentSizeForWidth(width)
            }

            contentHeight = calculatedHeight
        }

        backgroundView?.frame = bounds

        contentView?.frame = CGRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY + contentInsets.top,
            width: width,
            height: contentHeight
        )

        borderView.frame = CGRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY,
            width: width,
            height: bounds.height
        )
    }

    override var intrinsicContentSize: CGSize {
        let height: CGFloat

        if let preferredHeight = preferredHeight {
            height = preferredHeight
        } else {
            height = calculatedHeight + contentInsets.bottom + contentInsets.top
        }

        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: height
        )
    }

    private func setupLayout() {
        contentInsets = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        let shapeView = RoundedView()
        shapeView.shadowOpacity = 0.0
        shapeView.strokeWidth = 0.0
        shapeView.isUserInteractionEnabled = false
        shapeView.fillColor = .clear
        shapeView.cornerRadius = 0.0
        shapeView.roundingCorners = []
        backgroundView = shapeView

        borderView.isUserInteractionEnabled = false
        shapeView.addSubview(borderView)

        if contentView == nil {
            contentView = T()
        }

        contentView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        updateContentInteraction()
    }

    private func updateContentSizeForWidth(_ width: CGFloat) {
        calculatedWidth = width

        let size = rowContentView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .defaultLow
        )

        calculatedHeight = size.height

        invalidateIntrinsicContentSize()
    }

    private func updateContentInteraction() {
        contentView?.isUserInteractionEnabled = hasInteractableContent

        let color = hasInteractableContent ? R.color.colorCellBackgroundPressed()! : .clear
        roundedBackgroundView?.highlightedFillColor = color
    }
}
