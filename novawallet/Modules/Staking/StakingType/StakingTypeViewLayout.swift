import UIKit

final class StakingTypeViewLayout: ScrollableContainerLayoutView {
    let poolStakingBannerView: StakingTypeBannerView = .create {
        $0.imageView.image = R.image.iconPoolStakingType()
    }

    let directStakingBannerView: StakingTypeBannerView = .create {
        $0.imageView.image = R.image.iconDirectStakingType()
        $0.imageSize = .init(width: 128, height: 118)
        $0.imageOffsets = (top: -36, right: 28)
        $0.imageView.transform = .init(rotationAngle: 2.75762)
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(poolStakingBannerView, spacingAfter: 16)
        addArrangedSubview(directStakingBannerView)
    }

    private var attributesForDescription: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 8
        paragraphStyle.firstLineHeadIndent = 36

        let detailsAttributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle
        ]

        return detailsAttributes
    }
}
