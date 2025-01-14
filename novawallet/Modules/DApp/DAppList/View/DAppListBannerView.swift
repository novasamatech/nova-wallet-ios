import Foundation
import UIKit

class DAppListBannerView: UICollectionViewCell {
    let decorationView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 12.0
        view.clipsToBounds = true
    }

    let decorationTitleLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextPrimary()
        view.font = .semiBoldTitle3
        view.textAlignment = .left
        view.numberOfLines = 0
    }

    let decorationSubtitleLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextSecondary()
        view.font = .caption1
        view.textAlignment = .left
        view.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension DAppListBannerView {
    func setupLayout() {
        contentView.addSubview(decorationView)
        decorationView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        decorationView.addSubview(decorationTitleLabel)
        decorationTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.width.equalTo(200)
            make.top.equalToSuperview().inset(12.0)
        }

        decorationView.addSubview(decorationSubtitleLabel)
        decorationSubtitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.width.equalTo(200)
            make.top.equalTo(decorationTitleLabel.snp.bottom).offset(8.0)
            make.bottom.equalToSuperview().inset(12.0)
        }
    }
}

// MARK: Internal

extension DAppListBannerView {
    func bind(viewModel: DAppListBannerViewModel) {
        viewModel.imageViewModel.loadImage(
            on: decorationView,
            targetSize: decorationView.bounds.size,
            animated: true
        )

        decorationTitleLabel.text = viewModel.title
        decorationSubtitleLabel.text = viewModel.subtitle
    }
}
