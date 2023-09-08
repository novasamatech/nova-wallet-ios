import UIKit

final class StakingTypeViewLayout: ScrollableContainerLayoutView {
    let poolStakingBannerView: StakingTypeBannerView<StakingTypeAccountView> = .create {
        $0.imageView.image = R.image.imageStakingTypePool()!
        $0.accountView.genericViewSkeletonSize = CGSize(width: 24, height: 24)
        $0.imageSize = .init(width: 241, height: 185)
        $0.imageOffsets = (top: 0, right: 0)
    }

    let directStakingBannerView: StakingTypeBannerView<StakingTypeValidatorView> = .create {
        $0.imageView.image = R.image.imageStakingTypeDirect()!
        $0.imageSize = .init(width: 241, height: 185)
        $0.imageOffsets = (top: 0, right: 0)
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(poolStakingBannerView, spacingAfter: 16)
        addArrangedSubview(directStakingBannerView)
    }

    func bind(poolStakingTypeViewModel viewModel: PoolStakingTypeViewModel) {
        poolStakingBannerView.accountView.stopLoadingIfNeeded()

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
            poolStakingBannerView.accountView.startLoadingIfNeeded()
        }
    }

    func bind(directStakingTypeViewModel viewModel: DirectStakingTypeViewModel) {
        directStakingBannerView.accountView.stopLoadingIfNeeded()

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
            directStakingBannerView.accountView.startLoadingIfNeeded()
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
