import Foundation
import SoraUI

class BannerCollectionViewCell: CollectionViewContainerCell<BannerView> {
    override func prepareForReuse() {
        view.viewModel?.backgroundImage.cancel(on: view.backgroundImageView)
        view.viewModel?.contentImage.cancel(on: view.contentImageView)
    }
}

class BannerView: UIView {
    let containerView: UIView = .create { view in
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
    }

    let backgroundImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFill
    }

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
        addSubview(containerView)
        containerView.addSubview(backgroundImageView)
//        containerView.addSubview(contentImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(detailsLabel)

        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(8.0)
        }

        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16.0)
        }

        detailsLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).inset(8.0)
            make.leading.equalTo(titleLabel)
        }
    }

    func configure(with viewModel: BannerViewModel) {
        titleLabel.text = viewModel.title
        detailsLabel.text = viewModel.details
        containerView.clipsToBounds = viewModel.clipsToBounds

        viewModel.backgroundImage.loadImage(
            on: backgroundImageView,
            targetSize: bounds.size,
            animated: false
        )

//        viewModel.contentImage.loadImage(
//            on: contentImageView,
//            targetSize: bounds.size,
//            animated: false
//        )
    }
}
