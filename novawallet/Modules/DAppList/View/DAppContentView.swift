import UIKit

final class DAppContentView: UIView {
    let iconImageView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p0Paragraph
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .p2Paragraph
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.size.equalTo(64.0)
            make.bottom.lessThanOrEqualToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.top).offset(2.0)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.trailing.equalToSuperview()
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2.0)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.trailing.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview().offset(-2.0)
        }
    }
}
