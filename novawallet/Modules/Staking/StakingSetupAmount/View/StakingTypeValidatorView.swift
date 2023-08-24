import UIKit
import SnapKit

final class StakingTypeValidatorView: GenericStakingTypeAccountView<BorderedLabelView>, BindableView {
    var counterLabel: BorderedLabelView { rowContentView.titleView.fView }

    override func configure() {
        super.configure()

        counterLabel.contentInsets = .init(top: 6, left: 6, bottom: 5, right: 6)
        counterLabel.apply(style: .counter)
        counterLabel.titleLabel.textAlignment = .center
        counterLabel.snp.makeConstraints {
            $0.width.greaterThanOrEqualTo(counterLabel.snp.height)
        }
        genericViewSkeletonSize = CGSize(width: 24, height: 24)
    }

    func bind(viewModel: DirectStakingTypeAccountViewModel) {
        counterLabel.titleLabel.text = viewModel.count
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle

        if viewModel.isRecommended {
            subtitleLabel.apply(style: .init(
                textColor: R.color.colorTextPositive(),
                font: .caption1
            ))
        } else {
            subtitleLabel.apply(style: .caption1Secondary)
        }
    }
}
