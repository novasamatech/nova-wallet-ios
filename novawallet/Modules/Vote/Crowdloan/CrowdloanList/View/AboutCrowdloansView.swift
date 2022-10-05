import UIKit

final class AboutCrowdloansView: UIView {
    let aboutLabel: UILabel = .create {
        $0.font = .p1Paragraph
        $0.textColor = R.color.colorWhite()
    }

    let descriptionLabel: UILabel = .create {
        $0.font = .p2Paragraph
        $0.textColor = R.color.colorTransparentText()
        $0.lineBreakMode = .byWordWrapping
        $0.numberOfLines = 0
    }

    lazy var descriptionAttributes: [NSAttributedString.Key: Any] = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = Constants.descriptionLineHeightMultiple
        return [.paragraphStyle: paragraphStyle]
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
        addSubview(aboutLabel)
        aboutLabel.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(Constants.contentInsets)
        }

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview().inset(Constants.contentInsets)
            make.top.equalTo(aboutLabel.snp.bottom).offset(Constants.titleDescriptionSpace)
        }
    }
}

// MARK: - Bind

extension AboutCrowdloansView {
    struct Model {
        let title: String
        let subtitle: String
    }

    func bind(model: Model) {
        aboutLabel.text = model.title
        descriptionLabel.attributedText = .init(
            string: model.subtitle,
            attributes: descriptionAttributes
        )
    }
}

// MARK: - Constants

extension AboutCrowdloansView {
    private enum Constants {
        static let contentInsets: CGFloat = 16
        static let titleDescriptionSpace: CGFloat = 12
        static let descriptionLineHeightMultiple: CGFloat = 1.18
    }
}
