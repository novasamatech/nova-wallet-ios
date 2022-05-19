import UIKit

final class StackActionView: UIView {
    let iconImageView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorWhite()
        return label
    }()

    var detailsView: BorderedLabelView {
        internalDetailsView ?? setupDetailsView()
    }

    private var internalDetailsView: BorderedLabelView?

    let disclosureIndicatorView: UIView = {
        let imageView = UIImageView()
        let icon = R.image.iconSmallArrow()?.tinted(with: R.color.colorTransparentText()!)
        imageView.image = icon
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupDetailsView() -> BorderedLabelView {
        let view = BorderedLabelView()
        view.titleLabel.font = .semiBoldFootnote
        view.titleLabel.textColor = R.color.colorTransparentText()!
        view.contentInsets = UIEdgeInsets(top: 2, left: 8, bottom: 3, right: 8)

        internalDetailsView = view

        addSubview(view)

        titleLabel.snp.remakeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.centerY.equalToSuperview()
        }

        disclosureIndicatorView.snp.remakeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        view.snp.makeConstraints { make in
            make.trailing.equalTo(disclosureIndicatorView.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }

        return view
    }

    private func setupLayout() {
        addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.centerY.equalToSuperview()
        }

        addSubview(disclosureIndicatorView)
        disclosureIndicatorView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }
    }
}
