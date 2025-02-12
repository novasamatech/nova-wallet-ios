import Foundation
import SoraUI

class BannerCollectionViewCell: CollectionViewContainerCell<BannerView> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
    }

    private func setupStyle() {
        layer.cornerRadius = 12
    }

    func bind(with viewModel: BannerViewModel) {
        view.bind(with: viewModel)
        layer.masksToBounds = viewModel.clipsToBounds
    }
}

class BannerView: UIView {
    let contentImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldBodyPrimary)
    }

    let detailsLabel: UILabel = .create { view in
        view.apply(style: .caption1Primary)
        view.numberOfLines = 0
    }

    var viewModel: BannerViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let textContainer = UIStackView.vStack(
            alignment: .leading,
            spacing: 8.0,
            [titleLabel, detailsLabel]
        )

        addSubview(textContainer)
        addSubview(contentImageView)

        textContainer.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16.0)
            make.trailing.equalToSuperview().inset(127.0)
        }

        contentImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(-8.0)
            make.bottom.equalToSuperview().inset(-8.0)
            make.width.equalTo(202)
            make.trailing.equalToSuperview()
        }
    }

    func bind(with viewModel: BannerViewModel) {
        titleLabel.text = viewModel.title
        detailsLabel.text = viewModel.details
        contentImageView.image = viewModel.contentImage
        layer.masksToBounds = viewModel.clipsToBounds
    }
}
