import UIKit
import SoraUI

final class StakingTypeAccountView: RowView<GenericTitleValueView<IconDetailsGenericView<MultiValueView>, UIImageView>> {
    var iconImageView: UIImageView { rowContentView.titleView.imageView }
    var titleLabel: UILabel { rowContentView.titleView.detailsView.valueTop }
    var subtitleLabel: UILabel { rowContentView.titleView.detailsView.valueBottom }
    var disclosureImageView: UIImageView { rowContentView.valueView }

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
        roundedBackgroundView.apply(style: .roundedLightCell)
        preferredHeight = 52
        contentInsets = .init(top: 9, left: 16, bottom: 9, right: 14)
        borderView.borderType = .none

        titleLabel.textAlignment = .left
        subtitleLabel.textAlignment = .left
        titleLabel.apply(style: .footnotePrimary)
        subtitleLabel.apply(style: .init(
            textColor: R.color.colorTextPositive(),
            font: .caption1
        ))
        disclosureImageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorTextSecondary()!)
    }

    func bind(viewModel: StakingTypeAccountViewModel) {
        imageViewModel?.cancel(on: iconImageView)
        imageViewModel = viewModel.imageViewModel
        iconImageView.image = nil

        let imageSize = rowContentView.titleView.iconWidth
        viewModel.imageViewModel?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: imageSize, height: imageSize),
            animated: true
        )
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

        iconImageView.isHidden = viewModel.imageViewModel == nil
    }

    func bind(stakingTypeViewModel: LoadableViewModelState<StakingTypeViewModel>) {
        switch stakingTypeViewModel {
        case let .cached(value), let .loaded(value):
            bind(viewModel: .init(imageViewModel: nil, title: value.title, subtitle: value.subtitle, isRecommended: value.isRecommended))
        case .loading:
            // TODO:
            break
        }
    }
}
