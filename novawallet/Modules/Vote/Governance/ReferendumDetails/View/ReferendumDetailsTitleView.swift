import UIKit

final class ReferendumDetailsTitleView: UIView {
    let trackNameView: BorderedIconLabelView = .create {
        $0.iconDetailsView.spacing = 6
        $0.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        $0.iconDetailsView.detailsLabel.apply(style: .track)
        $0.backgroundView.apply(style: .referendum)
        $0.iconDetailsView.detailsLabel.numberOfLines = 1
    }

    let numberLabel: BorderedLabelView = .create {
        $0.titleLabel.apply(style: .track)
        $0.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        $0.backgroundView.apply(style: .referendum)
        $0.titleLabel.numberOfLines = 1
    }
    
    let addressView = PolkadotIconDetailsView()
    let infoImageView = UIImageView()
    let textView = UITextView()
    let moreButton = UIButton()
    
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
                        UIView(),
                        trackNameView,
                        numberLabel
                    ]),
                UIView.hStack(
                    spacing: 6,
                    [
                        addressView,
                        infoImageView,
                        UIView()
                    ]),
                textView,
                moreButton
            ]
        )
        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension ReferendumDetailsTitleView {
    struct Model {
        let track: Track?
        let accountIcon: DrawableIconViewModel?
        let accountName: String
        let title: String
        let description: String
        let buttonText: String
        
        struct Track {
            let titleIcon: TitleIconViewModel
            let referendumNumber: String?
        }
    }
    
    func bind(viewModel: Model) {
        numberLabel.isHidden = viewModel.track?.referendumNumber == nil
        trackNameView.iconDetailsView.bind(viewModel: viewModel.track?.titleIcon)
        numberLabel.titleLabel.text = viewModel.track?.referendumNumber
       
        viewModel.accountIcon.map {
            addressView.imageView.fillColor = $0.fillColor
            addressView.imageView.bind(icon: $0.icon)
        }
        addressView.titleLabel.text = viewModel.accountName
        
        let titleAttributedString = NSAttributedString(string: viewModel.title,
                                                       attributes: titleAttributes)
        let descriptionAttributedString = NSAttributedString(string: viewModel.description,
                                                             attributes: descriptionAttributes)
        let referndumInfo = NSMutableAttributedString()
        referndumInfo.append(titleAttributedString)
        referndumInfo.append(descriptionAttributedString)
        textView.attributedText = referndumInfo
        moreButton.setTitle(viewModel.buttonText, for: .normal)
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
