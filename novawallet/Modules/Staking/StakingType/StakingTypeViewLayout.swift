import UIKit

final class StakingTypeViewLayout: ScrollableContainerLayoutView {
    let poolStakingBannerView: StakingTypeBannerView = .create {
        $0.imageView.image = R.image.iconPoolStakingType()
    }

    let directStakingBannerView: StakingTypeBannerView = .create {
        $0.imageView.image = R.image.iconDirectStakingType()
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
        poolStakingBannerView.detailsLabel.attributedText = NSAttributedString(string: """
        \n\rMinimum stake: 1 DOT
        \n\rRewards: Claim manually
        """)

        poolStakingBannerView.setAction(viewModel: .init(
            imageViewModel: nil,
            title: "Nova Wallet — Pool #1",
            subtitle: "Recommended",
            isRecommended: true
        ))

        directStakingBannerView.titleLabel.text = "Direct staking"
        directStakingBannerView.detailsLabel.attributedText = NSAttributedString(string: """
        \n\rMinimum stake: 405 DOT
        \n\rRewards: Paid automatically
        \n\rReuse tokens in Governance
        \n\rAdvanced staking management
        """)
    }
}
