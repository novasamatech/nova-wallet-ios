import UIKit

final class WalletListEmptyCell: UICollectionViewCell {
    let backgroundBlurView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.sideLength = 12.0
        return view
    }()

    let iconView: UIImageView = {
        let view = UIImageView()
        view.image = R.image.iconLoadingError()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorWhite32()!)
        return view
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(text: String) {
        detailsLabel.text = text
    }

    private func setupLayout() {
        contentView.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.bottom.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.top.equalTo(backgroundBlurView.snp.top).offset(16.0)
            make.centerX.equalToSuperview()
        }

        contentView.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(0.0)
            make.leading.equalTo(backgroundBlurView).offset(16.0)
            make.trailing.equalTo(backgroundBlurView).offset(-16.0)
        }
    }
}
