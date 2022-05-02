import Foundation
import SoraUI
import UIKit

class RewardSelectionView: BackgroundedContentControl {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorWhite()
        return label
    }()

    let incomeLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorGreen()
        return label
    }()

    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldCaps1
        label.textColor = R.color.colorWhite()
        return label
    }()

    let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let selectorView = RadioSelectorView()

    let triangularedBackgroundView: TriangularedView = {
        let triangularedView = TriangularedView()
        triangularedView.isUserInteractionEnabled = false
        triangularedView.shadowOpacity = 0.0
        triangularedView.fillColor = R.color.colorWhite8()!
        triangularedView.highlightedFillColor = R.color.colorWhite8()!
        triangularedView.strokeColor = .clear
        triangularedView.highlightedStrokeColor = .clear

        return triangularedView
    }()

    var horizontalSpacing: CGFloat = 18.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var verticalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    override var isSelected: Bool {
        get {
            selectorView.selected
        }

        set {
            triangularedBackgroundView.isHighlighted = newValue
            selectorView.selected = newValue
        }
    }

    override var intrinsicContentSize: CGSize {
        let topContentHeight = max(titleLabel.intrinsicContentSize.height, amountLabel.intrinsicContentSize.height)
        let bottomContentHeight = max(incomeLabel.intrinsicContentSize.height, priceLabel.intrinsicContentSize.height)

        let height = contentInsets.top + topContentHeight + verticalSpacing
            + bottomContentHeight + contentInsets.bottom

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds

        layoutMiddleContent()
        layoutTopContent()
        layoutBottomContent()
    }

    private func layoutMiddleContent() {
        selectorView.frame = CGRect(
            x: contentInsets.left,
            y: bounds.midY - selectorView.outerRadius,
            width: 2 * selectorView.outerRadius,
            height: 2 * selectorView.outerRadius
        )
    }

    private func layoutTopContent() {
        let availableWidth = bounds.width - 2 * selectorView.outerRadius - 2 * horizontalSpacing - contentInsets.right

        let amountSize = amountLabel.intrinsicContentSize

        let amountClippedWidth = max(min(availableWidth, amountSize.width), 0.0)

        amountLabel.frame = CGRect(
            x: bounds.maxX - contentInsets.right - amountClippedWidth,
            y: bounds.minY + contentInsets.top,
            width: amountClippedWidth,
            height: amountSize.height
        )

        let titleSize = titleLabel.intrinsicContentSize

        let titleClippedWidth = max(min(availableWidth - amountClippedWidth, titleSize.width), 0)

        titleLabel.frame = CGRect(
            x: bounds.minX + contentInsets.left + 2 * selectorView.outerRadius + horizontalSpacing,
            y: bounds.minY + contentInsets.top,
            width: titleClippedWidth,
            height: titleSize.height
        )
    }

    private func layoutBottomContent() {
        let availableWidth = bounds.width - 2 * selectorView.outerRadius - 2 * horizontalSpacing - contentInsets.right

        let incomeSize = incomeLabel.intrinsicContentSize

        let incomeClippedWidth = max(min(availableWidth, incomeSize.width), 0.0)

        incomeLabel.frame = CGRect(
            x: bounds.minX + contentInsets.left + 2 * selectorView.outerRadius + horizontalSpacing,
            y: bounds.maxY - contentInsets.bottom - incomeSize.height,
            width: incomeClippedWidth,
            height: incomeSize.height
        )

        let priceSize = priceLabel.intrinsicContentSize

        let priceClippedWidth = max(min(availableWidth - incomeClippedWidth - horizontalSpacing, priceSize.width), 0)

        priceLabel.frame = CGRect(
            x: bounds.maxX - contentInsets.right - priceClippedWidth,
            y: bounds.maxY - contentInsets.bottom - priceSize.height,
            width: priceClippedWidth,
            height: priceSize.height
        )
    }

    // MARK: Configure

    private func configure() {
        backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            backgroundView = triangularedBackgroundView
        }
    }

    private func configureContentViewIfNeeded() {
        if contentView == nil {
            let contentView = UIView()
            contentView.backgroundColor = .clear
            contentView.isUserInteractionEnabled = false
            self.contentView = contentView
        }

        if titleLabel.superview == nil {
            contentView?.addSubview(titleLabel)
        }

        if amountLabel.superview == nil {
            contentView?.addSubview(amountLabel)
        }

        if priceLabel.superview == nil {
            contentView?.addSubview(priceLabel)
        }

        if incomeLabel.superview == nil {
            contentView?.addSubview(incomeLabel)
        }

        if selectorView.superview == nil {
            contentView?.addSubview(selectorView)
        }

        contentInsets = UIEdgeInsets(top: 10.0, left: 18.0, bottom: 10.0, right: 16.0)
    }
}
