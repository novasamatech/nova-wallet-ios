import UIKit
import UIKit_iOS

final class GradientBannerInfoView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldTitle3
        label.textColor = R.color.colorTextPrimary()
        label.numberOfLines = 0
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.numberOfLines = 0
        return label
    }()

    let imageView = UIImageView()

    var imageInsets: UIEdgeInsets = .zero {
        didSet {
            imageView.snp.remakeConstraints { make in
                make.top.equalToSuperview().inset(imageInsets.top)
                make.trailing.equalToSuperview().inset(imageInsets.right)
            }
        }
    }

    var textInsets: UIEdgeInsets = .zero {
        didSet {
            titleLabel.snp.updateConstraints { make in
                make.top.equalToSuperview().inset(textInsets.top)
                make.leading.equalToSuperview().inset(textInsets.left)
                make.trailing.equalTo(imageView.snp.leading).inset(textInsets.right)
            }

            subtitleLabel.snp.updateConstraints { make in
                make.bottom.equalToSuperview().inset(textInsets.bottom)
                make.leading.equalToSuperview().inset(textInsets.left)
                make.trailing.equalTo(imageView.snp.leading).inset(textInsets.right)
            }
        }
    }

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
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(imageInsets.top)
            make.trailing.equalToSuperview().inset(imageInsets.right)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.trailing.equalTo(imageView.snp.leading).offset(-16.0)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8.0)
            make.leading.bottom.equalToSuperview()
            make.trailing.equalTo(imageView.snp.leading).offset(-16.0)
        }

        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        subtitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
}
