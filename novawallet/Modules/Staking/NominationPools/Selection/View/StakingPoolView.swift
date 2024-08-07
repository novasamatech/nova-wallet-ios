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
        titleView.makeHorizontal()
        titleView.stackView.alignment = .center
        rewardView.spacing = 2
        rewardView.makeHorizontal()
        rewardView.fView.apply(style: .caption1Positive)
        rewardView.sView.apply(style: .caption1Secondary)
        rewardView.fView.setContentHuggingPriority(.high, for: .horizontal)
        rewardView.sView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueView.spacing = 8
        valueView.makeHorizontal()
        poolView.spacing = 2
        poolView.valueTop.apply(style: .footnotePrimary)
        poolName.textAlignment = .left
        poolName.setContentHuggingPriority(.defaultLow, for: .horizontal)
        iconView.setContentHuggingPriority(.defaultLow, for: .vertical)

        let icon = R.image.iconInfoFilled()
        infoButton.setImage(icon, for: .normal)
        iconView.snp.makeConstraints {
            $0.size.equalTo(Constants.iconSize)
        }
        membersCountLabel.apply(style: .footnotePrimary)
    }
}

extension StakingPoolView {
    enum Constants {
        static let iconSize = CGSize(width: 24, height: 24)
    }
}
