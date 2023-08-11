import UIKit
import SnapKit

typealias SelectPoolRewardView = GenericPairValueView<UILabel, UILabel>
typealias SelectPoolAccountView = GenericPairValueView<UIImageView, GenericMultiValueView<SelectPoolRewardView>>
typealias SelectPoolMembersView = GenericPairValueView<UILabel, UIButton>

final class StakingPoolView: GenericTitleValueView<SelectPoolAccountView, SelectPoolMembersView> {
    var iconView: UIImageView { titleView.fView }
    var poolView: GenericMultiValueView<SelectPoolRewardView> { titleView.sView }
    var poolName: UILabel { poolView.valueTop }
    var rewardView: SelectPoolRewardView { poolView.valueBottom }
    var membersCountLabel: UILabel { valueView.fView }
    var infoButton: UIButton { valueView.sView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        titleView.spacing = 12
        rewardView.spacing = 2
        valueView.spacing = 8
        poolView.spacing = 2

        poolView.valueTop.apply(style: .footnotePrimary)
        rewardView.fView.apply(style: .caption1Positive)
        rewardView.sView.apply(style: .caption1Tertiary)
        rewardView.makeHorizontal()
        valueView.makeHorizontal()
        titleView.makeHorizontal()
        poolName.textAlignment = .left
        poolName.setContentHuggingPriority(.defaultLow, for: .horizontal)
        rewardView.fView.setContentHuggingPriority(.high, for: .horizontal)
        rewardView.sView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        poolName.setContentCompressionResistancePriority(.required, for: .vertical)
        rewardView.fView.setContentCompressionResistancePriority(.required, for: .vertical)
        rewardView.sView.setContentCompressionResistancePriority(.required, for: .vertical)
        titleView.stackView.alignment = .center

        iconView.setContentHuggingPriority(.defaultLow, for: .vertical)

        let icon = R.image.iconInfoFilled()?.tinted(with: R.color.colorIconSecondary()!)
        infoButton.setImage(icon, for: .normal)

        iconView.snp.makeConstraints {
            $0.size.equalTo(Constants.iconSize)
        }
    }
}

extension StakingPoolView {
    enum Constants {
        static let iconSize = CGSize(width: 24, height: 24)
    }
}
