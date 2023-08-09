import UIKit

final class StakingTypeViewLayout: ScrollableContainerLayoutView {
    let poolStakingBannerView: StakingTypeBannerView<StakingTypeAccountView> = .create {
        $0.imageView.image = R.image.iconPoolStakingType()
    }

    let directStakingBannerView: StakingTypeBannerView<StakingTypeValidatorView> = .create {
        $0.imageView.image = R.image.iconDirectStakingType()
        $0.imageSize = .init(width: 128, height: 118)
        $0.imageOffsets = (top: -18, right: 28)
        $0.imageView.transform = .init(rotationAngle: 2.75762)
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(poolStakingBannerView, spacingAfter: 16)
        addArrangedSubview(directStakingBannerView)
    }

    func bind(poolStakingTypeViewModel viewModel: PoolStakingTypeViewModel) {
        poolStakingBannerView.titleLabel.text = viewModel.title
        poolStakingBannerView.detailsLabel.attributedText = NSAttributedString(
            string: viewModel.subtile,
            attributes: attributesForDescription
        )
        if let accountModel = viewModel.poolAccount {
            poolStakingBannerView.setAction(viewModel: .init(
                imageViewModel: accountModel.icon,
                title: accountModel.title,
                subtitle: accountModel.subtitle,
                isRecommended: accountModel.subtitle != nil
            ))
        } else {
            poolStakingBannerView.setAction(viewModel: nil)
        }
    }

    func bind(directStakingTypeViewModel viewModel: DirectStakingTypeViewModel) {
        directStakingBannerView.titleLabel.text = viewModel.title
        directStakingBannerView.detailsLabel.attributedText = NSAttributedString(
            string: viewModel.subtile,
            attributes: attributesForDescription
        )

        if let accountModel = viewModel.validator {
            directStakingBannerView.setAction(viewModel: .init(
                count: accountModel.count,
                title: accountModel.title,
                subtitle: accountModel.subtitle,
                isRecommended: accountModel.isRecommended
            ))
        } else {
            directStakingBannerView.setAction(viewModel: nil)
        }
    }

    private var attributesForDescription: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 8
        paragraphStyle.firstLineHeadIndent = 0
        let detailsAttributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle
        ]

        return detailsAttributes
    }
}
