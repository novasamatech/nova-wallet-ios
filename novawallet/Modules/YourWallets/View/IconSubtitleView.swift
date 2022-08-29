import UIKit
import SubstrateSdk

final class IconSubtitleView: UIView {
    private typealias Colors = R.color
    private typealias Fonts = R.font

    private(set) var model: Model?

    let imageView: UIImageView = .create {
        $0.contentMode = .center
    }

    let titleLabel: UILabel = .create {
        $0.textColor = Colors.colorWhite100()
        $0.font = .regularSubheadline
        $0.numberOfLines = 0
    }

    let subtitleImageView = PolkadotIconView()

    let subtitleLabel: UILabel = .create {
        $0.textColor = Colors.colorWhite64()
        $0.font = .regularFootnote
        $0.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let subtitleView = UIStackView(arrangedSubviews: [
            subtitleImageView,
            subtitleLabel
        ])
        subtitleView.spacing = Constants.horizontalSubtileViewSpace
        subtitleImageView.setContentCompressionResistancePriority(.required, for: .vertical)
        subtitleImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleView])
        textStackView.axis = .vertical
        textStackView.alignment = .leading
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.setContentHuggingPriority(.required, for: .vertical)

        let contentView = UIStackView(arrangedSubviews: [imageView, textStackView])
        contentView.spacing = Constants.horizontalSpace
        addSubview(contentView)

        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        subtitleImageView.snp.makeConstraints {
            $0.width.equalTo(Constants.subtitleImageViewSize)
            $0.height.equalTo(Constants.subtitleImageViewSize)
        }
    }
}

// MARK: - Model

extension IconSubtitleView {
    struct Model {
        let icon: ImageViewModelProtocol?
        let title: String
        let subtitle: String
        let subtitleIcon: DrawableIconViewModel?
        let lineBreakMode: NSLineBreakMode
    }

    func bind(model: Model) {
        self.model?.icon?.cancel(on: imageView)
        imageView.image = nil

        self.model = model

        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        subtitleLabel.lineBreakMode = model.lineBreakMode

        model.icon?.loadImage(
            on: imageView,
            targetSize: CGSize(width: 32, height: 32),
            animated: true
        )

        model.subtitleIcon.map {
            subtitleImageView.fillColor = $0.fillColor
            subtitleImageView.bind(icon: $0.icon)
        }
    }

    func clear() {
        model?.icon?.cancel(on: imageView)
        imageView.image = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
        model = nil
    }
}

//MARK: - Constants

extension IconSubtitleView {
    enum Constants {
        static let subtitleImageViewSize = CGSize(width: 18, height: 18)
        static let horizontalSpace: CGFloat = 12
        static let horizontalSubtileViewSpace: CGFloat = 4
    }
}
