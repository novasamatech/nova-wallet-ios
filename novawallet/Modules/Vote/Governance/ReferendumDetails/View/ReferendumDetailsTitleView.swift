import UIKit

final class ReferendumDetailsTitleView: UIView {
    let addressView = PolkadotIconDetailsView()
    let infoImageView = UIImageView()
    let textView: UITextView = .create {
        $0.isScrollEnabled = false
    }

    let moreButton: UIButton = .create {
        let color = R.color.colorAccent()!
        $0.titleLabel?.apply(style: .rowLink)
        $0.setImage(
            R.image.iconChevronRight()?.tinted(with: color),
            for: .normal
        )
        $0.setTitleColor(color, for: .normal)
        $0.semanticContentAttribute = .forceRightToLeft
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
        let content = UIView.vStack(
            spacing: 9,
            [
                UIView.hStack(
                    spacing: 6,
                    [
                        addressView,
                        infoImageView,
                        UIView()
                    ]
                ),
                textView,
                UIView.hStack([
                    moreButton,
                    UIView()
                ])
            ]
        )
        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        textView.snp.makeConstraints {
            $0.height.lessThanOrEqualTo(220)
        }
    }
}

extension ReferendumDetailsTitleView {
    struct Model {
        let accountIcon: DrawableIconViewModel?
        let accountName: String?
        let title: String
        let description: String
        let shouldReadMore: Bool
    }

    func bind(viewModel: Model) {
        viewModel.accountIcon.map {
            addressView.imageView.fillColor = $0.fillColor
            addressView.imageView.bind(icon: $0.icon)
        }
        addressView.titleLabel.text = viewModel.accountName

        addressView.isHidden = viewModel.accountIcon == nil && viewModel.accountName == nil

        let titleAttributedString = NSAttributedString(
            string: viewModel.title,
            attributes: titleAttributes
        )
        let descriptionAttributedString = NSAttributedString(
            string: viewModel.description,
            attributes: descriptionAttributes
        )
        let referendumInfo = NSMutableAttributedString()
        referendumInfo.append(titleAttributedString)
        referendumInfo.append(NSAttributedString(string: "\n"))
        referendumInfo.append(descriptionAttributedString)
        textView.attributedText = referendumInfo

        moreButton.isHidden = viewModel.shouldReadMore
    }

    private var titleAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        return [
            .font: UIFont.boldTitle1,
            .foregroundColor: R.color.colorWhite()!,
            .paragraphStyle: paragraphStyle
        ]
    }

    private var descriptionAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        return [
            .font: UIFont.regularSubheadline,
            .foregroundColor: R.color.colorWhite64()!,
            .paragraphStyle: paragraphStyle
        ]
    }
}
