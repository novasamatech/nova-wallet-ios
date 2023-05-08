import UIKit

final class WalletTotalAmountView: IconDetailsGenericView<MultiValueView> {
    var titleLabel: UILabel { detailsView.valueTop }
    var subtitleLabel: UILabel { detailsView.valueBottom }

    var imageViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
    }

    func setupStyle() {
        iconWidth = 32
        spacing = 12
        detailsView.spacing = 0

        titleLabel.apply(style: .regularSubhedlinePrimary)
        titleLabel.textAlignment = .left

        subtitleLabel.apply(style: .footnoteSecondary)
        subtitleLabel.textAlignment = .left
    }
}

extension WalletTotalAmountView {
    struct ViewModel {
        let icon: ImageViewModelProtocol?
        let name: String
        let amount: String
    }

    func cancelImageLoading() {
        imageViewModel?.cancel(on: imageView)
        imageView.image = nil
    }

    func bind(viewModel: ViewModel) {
        cancelImageLoading()

        imageViewModel = viewModel.icon
        imageViewModel?.loadImage(
            on: imageView,
            targetSize: CGSize(width: iconWidth, height: iconWidth),
            animated: true
        )

        titleLabel.text = viewModel.name
        subtitleLabel.text = viewModel.amount
    }
}
