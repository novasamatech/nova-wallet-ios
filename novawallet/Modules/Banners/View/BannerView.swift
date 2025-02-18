import Foundation
import SoraUI

class BannerCollectionViewCell: CollectionViewContainerCell<BannerView> {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    func bind(with viewModel: BannerViewModel) {
        view.bind(with: viewModel)
        contentView.layer.masksToBounds = viewModel.clipsToBounds
    }
}

class BannerView: UIView {
    let contentImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldBodyPrimary)
        view.numberOfLines = 0
    }

    let detailsLabel: UILabel = .create { view in
        view.apply(style: .caption1Primary)
        view.numberOfLines = 0
    }

    var viewModel: BannerViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension BannerView {
    func setupLayout() {
        let textContainer = UIStackView.vStack(
            alignment: .leading,
            spacing: Constants.textSpacing,
            [titleLabel, detailsLabel]
        )

        addSubview(textContainer)
        addSubview(contentImageView)

        textContainer.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(Constants.textContainerBottomInset).priority(.high)
            make.top.equalToSuperview().inset(Constants.textContainerTopInset).priority(.high)
            make.leading.equalToSuperview().inset(Constants.textContainerTopInset)
            make.width.equalTo(Constants.textContainerWidth)
        }

        contentImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(-Constants.contentImageViewVerticalInset)
            make.bottom.equalToSuperview().inset(-Constants.contentImageViewVerticalInset)
            make.width.equalTo(Constants.contentImageViewWidth)
            make.trailing.equalToSuperview()
        }
    }

    func setupStyle() {
        layer.cornerRadius = Constants.cornerRadius
    }
}

// MARK: Internal

extension BannerView {
    func bind(with viewModel: BannerViewModel) {
        titleLabel.text = viewModel.title
        detailsLabel.text = viewModel.details
        contentImageView.image = viewModel.contentImage
        clipsToBounds = viewModel.clipsToBounds
        layer.masksToBounds = viewModel.clipsToBounds
    }
}

// MARK: Constants

extension BannerView {
    enum Constants {
        static let textContainerTopInset: CGFloat = 16.0
        static let textContainerBottomInset: CGFloat = 36.0
        static let textContainerWidth: CGFloat = 200
        static let textSpacing: CGFloat = 8.0
        static let contentImageViewWidth: CGFloat = 202
        static let contentImageViewVerticalInset: CGFloat = 8.0
        static let cornerRadius: CGFloat = 12.0
    }
}
