import Foundation
import UIKit
import UIKit_iOS

final class WarningView: GenericBorderedView<
    GenericPairValueView<
        UIImageView,
        GenericPairValueView<
            UILabel,
            GenericMultiValueView<UIView>
        >
    >
> {
    var learnMoreButton = UIButton()

    private var warningIconView: UIImageView {
        contentView.fView
    }

    private var titleLabel: UILabel {
        contentView.sView.fView
    }

    private var messageLabel: UILabel {
        contentView.sView.sView.valueTop
    }

    private var learnMoreButtonContainer: UIView {
        contentView.sView.sView.valueBottom
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }
}

// MARK: - Private

private extension WarningView {
    func setupLayout() {
        contentView.makeHorizontal()
        contentView.stackView.alignment = .top

        contentView.spacing = Constants.warningToContent
        contentView.sView.sView.spacing = Constants.titleToMessage

        contentInsets = Constants.contentInsets

        warningIconView.snp.makeConstraints { make in
            make.width.equalTo(Constants.warningViewSize)
        }

        learnMoreButtonContainer.addSubview(learnMoreButton)
        learnMoreButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        learnMoreButtonContainer.snp.makeConstraints { make in
            make.height.equalTo(Constants.learnMoreActionHeight)
        }
    }

    func setupStyle() {
        backgroundView.cornerRadius = Constants.cornerRadius
        backgroundView.fillColor = R.color.colorWarningBlockBackground()!

        warningIconView.image = R.image.iconWarning()
        warningIconView.contentMode = .scaleAspectFit

        titleLabel.apply(style: .caption1Primary)
        messageLabel.apply(style: .caption1Secondary)

        titleLabel.numberOfLines = 0
        messageLabel.numberOfLines = 0

        titleLabel.textAlignment = .left
        messageLabel.textAlignment = .left
    }
}

// MARK: - Internal

extension WarningView {
    func bind(_ viewModel: Model) {
        titleLabel.text = viewModel.title

        if let message = viewModel.message {
            messageLabel.text = message
            messageLabel.isHidden = false
        } else {
            messageLabel.isHidden = true
        }

        if let learnMoreViewModel = viewModel.learnMore {
            learnMoreButton.bindLearnMore(
                learnMoreText: learnMoreViewModel.title,
                style: .caption1Accent
            )
            learnMoreButtonContainer.isHidden = false
        } else {
            learnMoreButtonContainer.isHidden = true
        }
    }
}

// MARK: - View Model

extension WarningView {
    struct Model {
        let title: String
        let message: String?
        let learnMore: LearnMoreViewModel?
    }
}

// MARK: - Constants

private extension WarningView {
    enum Constants {
        static let warningToContent: CGFloat = 12
        static let titleToMessage: CGFloat = 8

        static let contentInsets: UIEdgeInsets = .init(
            top: 10.0,
            left: 12.0,
            bottom: 10.0,
            right: 12.0
        )
        static let cornerRadius: CGFloat = 12

        static let warningViewSize: CGFloat = 16
        static let learnMoreActionHeight: CGFloat = 32
    }
}
