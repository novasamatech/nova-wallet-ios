import UIKit

typealias SwapIconDetailsView = GenericPairValueView<IconDetailsView, FlexibleSpaceView>

final class SwapAssetView: GenericPairValueView<SwapIconDetailsView, IconDetailsView> {
    var assetLabel: UILabel { fView.fView.detailsLabel }
    var disclosureImageView: UIImageView { fView.fView.imageView }
    var hubNameView: UILabel { sView.detailsLabel }
    var hubImageView: UIImageView { sView.imageView }

    private var imageViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        fView.makeHorizontal()
        fView.fView.spacing = 0
        fView.fView.iconWidth = 20
        fView.fView.mode = .detailsIcon
        hubNameView.numberOfLines = 1
        assetLabel.numberOfLines = 1

        sView.spacing = 8
        sView.iconWidth = 16
        sView.mode = .iconDetails

        spacing = 4
        makeVertical()

        assetLabel.apply(style: .semiboldBodyPrimary)
        hubNameView.apply(style: .footnoteSecondary)
    }

    override var intrinsicContentSize: CGSize {
        let assetViewWidth = assetLabel.intrinsicContentSize.width + iconWidth + fView.fView.iconWidth
        let hubViewWidth = iconWidth + iconSpacing + hubNameView.intrinsicContentSize.width
        let width: CGFloat = max(assetViewWidth, hubViewWidth)
        let assetHeight = max(assetLabel.intrinsicContentSize.height, iconWidth)
        let hubViewHeight = max(hubNameView.intrinsicContentSize.height, iconWidth)
        let height = assetHeight + spacing + hubViewHeight
        return .init(
            width: width,
            height: height
        )
    }

    private var iconWidth: CGFloat {
        imageViewModel == nil ? 0 : fView.fView.iconWidth
    }

    private var iconSpacing: CGFloat {
        imageViewModel == nil ? 0 : sView.spacing
    }

    func bind(symbol: String, network: String, icon: ImageViewModelProtocol?) {
        assetLabel.text = symbol
        imageViewModel?.cancel(on: hubImageView)
        imageViewModel = icon
        icon?.loadImage(
            on: hubImageView,
            targetSize: .init(
                width: sView.iconWidth,
                height: sView.iconWidth
            ),
            animated: true
        )
        sView.hidesIcon = icon == nil
        hubNameView.text = network
        disclosureImageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        invalidateIntrinsicContentSize()
    }
}
