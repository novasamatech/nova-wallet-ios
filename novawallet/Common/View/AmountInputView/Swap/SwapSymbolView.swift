import UIKit

final class SwapSymbolView: GenericPairValueView<GenericPairValueView<IconDetailsView, FlexibleSpaceView>, IconDetailsView> {
    var symbolLabel: UILabel { fView.fView.detailsLabel }
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

    func configure() {
        fView.makeHorizontal()
        fView.fView.spacing = 0
        fView.fView.iconWidth = 20
        fView.fView.mode = .detailsIcon

        sView.spacing = 8
        sView.iconWidth = 16
        sView.mode = .iconDetails

        spacing = 4
        makeVertical()

        symbolLabel.apply(style: .semiboldBodyPrimary)
        hubNameView.apply(style: .footnoteSecondary)
    }

    override var intrinsicContentSize: CGSize {
        let symbolWidth = symbolLabel.intrinsicContentSize.width + fView.fView.iconWidth
        let hubWidth = sView.iconWidth + sView.spacing + hubNameView.intrinsicContentSize.width
        let width: CGFloat = max(symbolWidth, hubWidth)
        let symbolHeight = max(symbolLabel.intrinsicContentSize.height, fView.fView.iconWidth)
        let hubHeight = max(hubNameView.intrinsicContentSize.height, sView.iconWidth)
        let height = symbolHeight + spacing + hubHeight
        return .init(
            width: width,
            height: height
        )
    }

    func bind(symbol: String, network: String, icon: ImageViewModelProtocol?) {
        symbolLabel.text = symbol
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
