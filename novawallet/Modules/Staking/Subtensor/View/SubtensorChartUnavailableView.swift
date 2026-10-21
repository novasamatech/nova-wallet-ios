import UIKit

final class SubtensorChartUnavailableView: UIControl {
    let iconView: UIImageView = .create { view in
        view.image = R.image.iconInfoFilled()
        view.contentMode = .scaleAspectFit
    }

    let titleLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
        label.textAlignment = .center
        label.numberOfLines = 0
    }

    let detailsLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.textAlignment = .center
        label.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 16

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String, details: String, isAction: Bool) {
        detailsLabel.apply(style: isAction ? .caption1Accent : .caption1Secondary)
        titleLabel.apply(text: title, lineHeight: 18)
        detailsLabel.apply(text: details, lineHeight: 16)
        isUserInteractionEnabled = isAction
    }
}

private extension SubtensorChartUnavailableView {
    func setupLayout() {
        let contentView = UIView.vStack(alignment: .center, spacing: 8, [iconView, titleLabel, detailsLabel])
        contentView.isUserInteractionEnabled = false

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().inset(24)
            make.trailing.lessThanOrEqualToSuperview().inset(24)
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(24)
        }
    }
}
