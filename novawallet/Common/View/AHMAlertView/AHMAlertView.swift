import Foundation
import UIKit_iOS

final class AHMAlertView: GenericBorderedView<
    GenericPairValueView<
        GenericPairValueView<
            UIImageView,
            GenericPairValueView<
                GenericPairValueView<
                    UILabel,
                    TriangularedButton
                >,
                GenericMultiValueView<UIView>
            >
        >,
        TriangularedButton
    >
> {
    var closeButton: TriangularedButton {
        contentView.fView.sView.fView.sView
    }

    var learnMoreButton = UIButton()

    var actionButton: TriangularedButton {
        contentView.sView
    }

    private var infoIconView: UIImageView {
        contentView.fView.fView
    }

    private var titleLabel: UILabel {
        contentView.fView.sView.fView.fView
    }

    private var messageLabel: UILabel {
        contentView.fView.sView.sView.valueTop
    }

    private var learnMoreButtonContainer: UIView {
        contentView.fView.sView.sView.valueBottom
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }
}

// MARK: - Private

private extension AHMAlertView {
    func setupLayout() {
        contentView.fView.makeHorizontal()
        contentView.fView.stackView.alignment = .top

        contentView.spacing = Constants.contentToButton
        contentView.fView.spacing = Constants.infoToContent
        contentView.fView.sView.sView.spacing = Constants.titleToMessage

        contentView.fView.sView.fView.makeHorizontal()
        contentView.fView.sView.fView.stackView.alignment = .top

        contentInsets = Constants.contentInsets

        actionButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        infoIconView.snp.makeConstraints { make in
            make.width.equalTo(Constants.infoViewSize)
        }

        closeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.closeButtonSize)
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
        backgroundView.fillColor = R.color.colorInfoBlockBackground()!

        infoIconView.image = R.image.iconInfoAccent()
        infoIconView.contentMode = .scaleAspectFit

        closeButton.contentInsets.top = .zero
        closeButton.contentInsets.left += Constants.closButtonAdditionalSideInset
        closeButton.contentInsets.right += Constants.closButtonAdditionalSideInset
        closeButton.applyEnabledStyle(colored: .clear)
        closeButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 0
        closeButton.imageWithTitleView?.iconImage = R.image.iconBannerClose()

        titleLabel.apply(style: .caption1Primary)
        messageLabel.apply(style: .caption1Secondary)

        titleLabel.numberOfLines = 0
        messageLabel.numberOfLines = 0

        titleLabel.textAlignment = .left
        messageLabel.textAlignment = .left

        actionButton.applySecondaryEnabledAccentStyle()
    }
}

// MARK: - Internal

extension AHMAlertView {
    func bind(_ viewModel: Model) {
        titleLabel.text = viewModel.title

        let contentInsets = if viewModel.actionTitle != nil {
            Constants.contentInsets
        } else {
            Constants.hiddenActionContentInsets
        }

        self.contentInsets = contentInsets

        if let message = viewModel.message {
            messageLabel.text = message
            messageLabel.isHidden = false
        } else {
            messageLabel.isHidden = true
        }

        if let actionTitle = viewModel.actionTitle {
            actionButton.imageWithTitleView?.title = actionTitle
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }

        learnMoreButton.bindLearnMore(
            learnMoreText: viewModel.learnMore.title,
            style: .caption1Secondary
        )
    }
}

// MARK: - View Model

extension AHMAlertView {
    struct Model {
        let title: String
        let message: String?
        let learnMore: LearnMoreViewModel
        let actionTitle: String?
    }
}

// MARK: - Constants

private extension AHMAlertView {
    enum Constants {
        static let contentToButton: CGFloat = 8
        static let infoToContent: CGFloat = 12
        static let titleToMessage: CGFloat = 8

        static let contentInsets: UIEdgeInsets = .init(
            top: 10.0,
            left: 12.0,
            bottom: 12.0,
            right: 12.0
        )
        static let hiddenActionContentInsets: UIEdgeInsets = .init(
            top: 10.0,
            left: 12.0,
            bottom: 4.0,
            right: 12.0
        )
        static let cornerRadius: CGFloat = 12

        static let infoViewSize: CGFloat = 16
        static let closeButtonSize: CGFloat = 24
        static let learnMoreActionHeight: CGFloat = 32
        static let closButtonAdditionalSideInset: CGFloat = 4
    }
}
