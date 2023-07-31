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

        fill()
    }

    func fill() {
        poolStakingBannerView.titleLabel.text = "Pool staking"
        poolStakingBannerView.radioSelectorView.selected = true
        poolStakingBannerView.backgroundView.isHighlighted = true

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 8
        paragraphStyle.firstLineHeadIndent = 36

        let detailsAttributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle
        ]
        poolStakingBannerView.detailsLabel.attributedText = NSAttributedString(string: """
        Minimum stake: 1 DOT
        Rewards: Claim manually
        """, attributes: detailsAttributes)

        poolStakingBannerView.setAction(viewModel: .init(
            imageViewModel: nil,
            title: "Nova Wallet — Pool #1",
            subtitle: "Recommended",
            isRecommended: true
        ))

        directStakingBannerView.titleLabel.text = "Direct staking"
        directStakingBannerView.detailsLabel.attributedText = NSAttributedString(string: """
        Minimum stake: 405 DOT
        Rewards: Paid automatically
        Reuse tokens in Governance
        Advanced staking management
        """, attributes: detailsAttributes)
    }
}
