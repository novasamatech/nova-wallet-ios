import UIKit

final class EmptyCellContentView: UIView {
    let backgroundBlurView: BlockBackgroundView = .create {
        $0.sideLength = 12
    }

    let iconView: UIImageView = .create {
        $0.image = R.image.iconLoadingError()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorIconSecondary()!)
    }

    let detailsLabel = UILabel(
        style: .footnoteSecondary,
        textAlignment: .center,
        numberOfLines: 0
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 180)
    }

    private func setupLayout() {
        addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.bottom.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.top.equalTo(backgroundBlurView.snp.top).offset(16)
            make.centerX.equalToSuperview()
        }

        addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom)
            make.leading.equalTo(backgroundBlurView).offset(16)
            make.trailing.equalTo(backgroundBlurView).offset(-16)
        }
    }

    func bind(text: String) {
        detailsLabel.text = text
    }
}
