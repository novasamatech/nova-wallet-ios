import UIKit
import UIKit_iOS

final class StakingTypeAccountView: GenericStakingTypeAccountView<UIImageView>, BindableView {
    var iconImageView: UIImageView { rowContentView.titleView.fView }
    private var imageViewModel: ImageViewModelProtocol?
    let imageWidth: CGFloat = 24

    override func configure() {
        super.configure()

        iconImageView.snp.makeConstraints { make in
            make.width.equalTo(imageWidth)
        }

        iconImageView.contentMode = .scaleAspectFit
    }

    func bind(viewModel: StakingTypeAccountViewModel) {
        imageViewModel?.cancel(on: iconImageView)
        imageViewModel = viewModel.imageViewModel
        iconImageView.image = nil

        viewModel.imageViewModel?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: imageWidth, height: imageWidth),
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
}
