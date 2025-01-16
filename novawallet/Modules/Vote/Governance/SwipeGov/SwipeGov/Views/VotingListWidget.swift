import UIKit_iOS
import UIKit

enum VotingListWidgetViewModel {
    case votings(value: String, title: String)
    case empty(value: String, title: String)
}

class VotingListWidget: UIView {
    let contentView: GenericPairValueView<
        GenericPairValueView<
            BorderedLabelView,
            UILabel
        >,
        UIImageView
    > = .create { view in
        view.fView.stackView.distribution = .equalCentering
        view.fView.stackView.alignment = .center
    }

    var counterView: BorderedLabelView {
        contentView.fView.fView
    }

    var titleLabel: UILabel {
        contentView.fView.sView
    }

    var accessoryView: UIImageView {
        contentView.sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(with viewModel: VotingListWidgetViewModel) {
        switch viewModel {
        case let .votings(value, title):
            counterView.backgroundView.fillColor = R.color.colorIconAccent()!
            counterView.titleLabel.apply(style: .semiboldCaps2Primary)
            titleLabel.apply(style: .footnotePrimary)

            counterView.titleLabel.text = value
            titleLabel.text = title

            isUserInteractionEnabled = true
        case let .empty(value, title):
            counterView.backgroundView.fillColor = R.color.colorIconInactive()!
            counterView.titleLabel.apply(style: .semiboldCaps2Inactive)
            titleLabel.apply(style: .semiboldFootnoteButtonInactive)

            counterView.titleLabel.text = value
            titleLabel.text = title

            isUserInteractionEnabled = false
        }
    }
}

// MARK: Private

private extension VotingListWidget {
    private func setupLayout() {
        contentView.makeHorizontal()
        contentView.fView.setHorizontalAndSpacing(Constants.contentSpacing)

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.height.equalTo(Constants.contentHeight)
            make.leading.equalToSuperview().inset(Constants.contentInsets.left)
            make.trailing.equalToSuperview().inset(Constants.contentInsets.right)
            make.top.equalToSuperview().inset(Constants.contentInsets.top)
            make.bottom.equalToSuperview().inset(Constants.contentInsets.bottom)
        }

        accessoryView.snp.makeConstraints { make in
            make.width.height.equalTo(Constants.accessoryViewHeight)
        }
        accessoryView.contentMode = .scaleAspectFit
    }

    private func setupStyle() {
        backgroundColor = .clear

        counterView.backgroundView.fillColor = R.color.colorIconAccent()!
        counterView.titleLabel.apply(style: .semiboldCaps2Primary)
        counterView.contentInsets = Constants.counterContentInsets
        counterView.backgroundView.cornerRadius = Constants.counterViewCornerRadius

        titleLabel.apply(style: .footnotePrimary)

        accessoryView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)

        backgroundColor = R.color.colorChipsBackground()!
        layer.borderColor = R.color.colorContainerBorder()?.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = (
            Constants.contentHeight
                + Constants.contentInsets.top
                + Constants.contentInsets.bottom
        ) / 2
    }
}

// MARK: Constants

private extension VotingListWidget {
    enum Constants {
        static let contentHeight: CGFloat = 20
        static let accessoryViewHeight: CGFloat = 20
        static let counterViewCornerRadius: CGFloat = 6
        static let contentSpacing: CGFloat = 8
        static let contentInsets = UIEdgeInsets(
            top: 6.0,
            left: 12.0,
            bottom: 6.0,
            right: 8.0
        )
        static let counterContentInsets = UIEdgeInsets(
            top: 4,
            left: 8,
            bottom: 4,
            right: 8
        )
    }
}
