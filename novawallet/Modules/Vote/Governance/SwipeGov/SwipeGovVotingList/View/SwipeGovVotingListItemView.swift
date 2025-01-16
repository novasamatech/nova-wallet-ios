import UIKit
import UIKit_iOS

class SwipeGovVotingListItemCell: PlainBaseTableViewCell<SwipeGovVotingListItemView> {
    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
    }

    func bind(viewModel: SwipeGovVotingListItemViewModel) {
        contentDisplayView.bind(viewModel: viewModel)
    }
}

class SwipeGovVotingListItemView: GenericPairValueView<
    GenericPairValueView<
        BorderedLabelView,
        GenericMultiValueView<TitleValueView>
    >,
    UIImageView
> {
    private var mainContentView: GenericPairValueView<
        BorderedLabelView,
        GenericMultiValueView<TitleValueView>
    > {
        fView
    }

    private var referendumIndexView: BorderedLabelView {
        mainContentView.fView
    }

    private var titleLabel: UILabel {
        mainContentView.sView.valueTop
    }

    private var voteValueView: TitleValueView {
        mainContentView.sView.valueBottom
    }

    private var voteTypeLabel: UILabel {
        voteValueView.titleLabel
    }

    private var votesCountLabel: UILabel {
        voteValueView.valueLabel
    }

    private var accessoryView: UIImageView {
        sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    func bind(viewModel: SwipeGovVotingListItemViewModel) {
        referendumIndexView.titleLabel.text = viewModel.indexText
        titleLabel.text = viewModel.titleText
        votesCountLabel.text = viewModel.votesCountText
        voteTypeLabel.text = viewModel.voteType.text()

        switch viewModel.voteType {
        case .aye:
            voteTypeLabel.textColor = R.color.colorTextPositive()
        case .nay:
            voteTypeLabel.textColor = R.color.colorTextNegative()
        case .abstain:
            voteTypeLabel.textColor = R.color.colorTextSecondary()
        }
    }
}

// MARK: Private

private extension SwipeGovVotingListItemView {
    func setupLayout() {
        setHorizontalAndSpacing(Constants.accessoryViewOffset)
        mainContentView.setHorizontalAndSpacing(Constants.mainContentInnerSpacing)
        mainContentView.stackView.alignment = .center

        mainContentView.sView.spacing = Constants.titleValueSpacing
        mainContentView.sView.stackView.alignment = .leading
        mainContentView.sView.stackView.distribution = .fillEqually
    }

    func setupStyle() {
        referendumIndexView.backgroundView.cornerRadius = Constants.indexViewCornerRadius
        referendumIndexView.backgroundView.fillColor = R.color.colorChipsBackground()!
        referendumIndexView.titleLabel.apply(style: .semiboldCaps1ChipText)
        referendumIndexView.contentInsets = Constants.indexViewInnerInsets

        titleLabel.apply(style: .footnotePrimary)
        titleLabel.textAlignment = .left

        voteTypeLabel.apply(style: .caption1Secondary)
        votesCountLabel.apply(style: .caption1Secondary)

        voteValueView.borderView.borderType = .none

        accessoryView.image = R.image.iconInfoFilled()
        accessoryView.contentMode = .scaleAspectFit
    }
}

// MARK: Constants

private extension SwipeGovVotingListItemView {
    enum Constants {
        static let accessoryViewOffset: CGFloat = 16.0
        static let mainContentInnerSpacing: CGFloat = 8.0
        static let titleValueSpacing: CGFloat = 4.0
        static let voteValueSpacing: CGFloat = 2.0
        static let indexViewCornerRadius: CGFloat = 8.0

        static let indexViewInnerInsets = UIEdgeInsets(
            top: 6,
            left: 9,
            bottom: 6,
            right: 9
        )
    }
}
