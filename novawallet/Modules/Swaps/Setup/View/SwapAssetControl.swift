import UIKit
import SoraUI

final class SwapAssetControl: BackgroundedContentControl {
    var iconView: AssetIconView { lazyIconViewOrCreateIfNeeded() }
    private var lazyIconView: AssetIconView?

    let assetView = SwapAssetView()

    var iconViewContentInsets = UIEdgeInsets.zero {
        didSet {
            lazyIconView?.contentInsets = iconViewContentInsets
            setNeedsLayout()
        }
    }

    var horizontalSpacing: CGFloat = 8 {
        didSet {
            setNeedsLayout()
        }
    }

    var iconRadius: CGFloat = 16 {
        didSet {
            lazyIconView?.backgroundView.cornerRadius = iconRadius

            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let contentHeight = max(
            lazyIconView?.intrinsicContentSize.height ?? 0.0,
            assetView.intrinsicContentSize.height
        )

        let iconWidth = lazyIconView.map { $0.intrinsicContentSize.width + horizontalSpacing } ?? 0
        let contentWidth = iconWidth + assetView.intrinsicContentSize.width

        let height = contentInsets.top + contentHeight + contentInsets.bottom
        let width = contentInsets.left + contentWidth + contentInsets.right

        return CGSize(width: width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds

        layoutContent()
    }

    private func layoutContent() {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right
        let assetViewSize = assetView.intrinsicContentSize

        if let iconView = lazyIconView {
            iconView.frame = CGRect(
                x: bounds.minX + contentInsets.left,
                y: bounds.midY - iconRadius,
                width: 2.0 * iconRadius,
                height: 2.0 * iconRadius
            )

            assetView.frame = CGRect(
                x: iconView.frame.maxX + horizontalSpacing,
                y: bounds.midY - assetViewSize.height / 2.0,
                width: min(availableWidth, assetViewSize.width),
                height: assetViewSize.height
            )
        } else {
            assetView.frame = CGRect(
                x: contentInsets.left,
                y: bounds.midY - assetViewSize.height / 2.0,
                width: min(availableWidth, assetViewSize.width),
                height: assetViewSize.height
            )
        }
    }

    private func configure() {
        backgroundColor = UIColor.clear

        if contentView == nil {
            let contentView = UIView()
            contentView.backgroundColor = .clear
            contentView.isUserInteractionEnabled = false
            self.contentView = contentView
        }

        contentView?.addSubview(assetView)
    }

    private func lazyIconViewOrCreateIfNeeded() -> AssetIconView {
        if let iconView = lazyIconView {
            return iconView
        }

        let size = 2 * iconRadius
        let initFrame = CGRect(origin: .zero, size: .init(width: size, height: size))
        let imageView = AssetIconView(frame: initFrame)
        imageView.contentInsets = iconViewContentInsets
        imageView.backgroundView.cornerRadius = iconRadius
        contentView?.addSubview(imageView)

        lazyIconView = imageView

        if superview != nil {
            setNeedsLayout()
        }

        return imageView
    }
}

extension SwapAssetControl {
    func bind(assetViewModel: SwapsAssetViewModel) {
        let width = 2 * iconRadius - iconView.contentInsets.left - iconView.contentInsets.right
        let height = 2 * iconRadius - iconView.contentInsets.top - iconView.contentInsets.bottom
        iconViewContentInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        let size = CGSize(width: width, height: height)
        iconView.bind(viewModel: assetViewModel.imageViewModel, size: size)

        assetView.bind(
            symbol: assetViewModel.symbol,
            network: assetViewModel.hub.name,
            icon: assetViewModel.hub.icon
        )
        invalidateIntrinsicContentSize()
    }

    func bind(emptyViewModel: EmptySwapsAssetViewModel) {
        let size = CGSize(width: 2 * iconRadius, height: 2 * iconRadius)
        iconView.bind(viewModel: emptyViewModel.imageViewModel, size: size)
        iconViewContentInsets = .zero
        assetView.bind(
            symbol: emptyViewModel.title,
            network: emptyViewModel.subtitle,
            icon: nil
        )
        invalidateIntrinsicContentSize()
    }
}
