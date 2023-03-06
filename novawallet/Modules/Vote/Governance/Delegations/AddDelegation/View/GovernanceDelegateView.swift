import UIKit
import SoraUI

final class GovernanceDelegateView: UIView {
    private enum Constants {
        static let iconSize = CGSize(width: 40, height: 40)
        static var iconRadius: CGFloat { iconSize.height / 2 }
    }

    let nameLabel = UILabel(style: .regularSubhedlinePrimary, numberOfLines: 1)
    let typeView = GovernanceDelegateTypeView()

    private var typeStack: UIStackView?
    private var statsStack: UIStackView?

    let descriptionLabel = UILabel(style: .footnoteSecondary)
    let delegationsTitleLabel = UILabel(style: .caption2Secondary, numberOfLines: 0)
    let delegationsValueLabel = UILabel(style: .footnotePrimary, numberOfLines: 1)
    let votesTitleLabel = UILabel(style: .caption2Secondary, numberOfLines: 0)
    let votesValueLabel = UILabel(style: .footnotePrimary, numberOfLines: 1)
    let lastVotesTitleLabel = UILabel(style: .caption2Secondary, numberOfLines: 0)
    let lastVotesValueLabel = UILabel(style: .footnotePrimary, numberOfLines: 1)

    let avatarView: DAppIconView = .create {
        $0.contentInsets = .zero
    }

    private var viewModel: Model?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let typeStack = UIView.hStack([
            typeView,
            UIView()
        ])

        let statsStack = UIView.hStack(spacing: 12, [
            .vStack([
                delegationsTitleLabel,
                delegationsValueLabel
            ]),
            Self.dividerView(),
            .vStack([
                votesTitleLabel,
                votesValueLabel
            ]),
            Self.dividerView(),
            .vStack([
                lastVotesTitleLabel,
                lastVotesValueLabel
            ]),
            UIView()
        ])

        let contentView = UIView.vStack(spacing: 16, [
            .hStack(alignment: .center, spacing: 12, [
                avatarView,
                .vStack(spacing: 4, [
                    nameLabel,
                    typeStack
                ])
            ]),
            descriptionLabel,
            statsStack
        ])

        self.typeStack = typeStack
        self.statsStack = statsStack

        delegationsTitleLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
        votesTitleLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
        lastVotesTitleLabel.setContentHuggingPriority(.defaultLow, for: .vertical)

        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        avatarView.snp.makeConstraints {
            $0.size.equalTo(Constants.iconSize)
        }
    }

    private static func dividerView() -> UIView {
        let dividerView = UIView()
        dividerView.backgroundColor = R.color.colorDivider()
        dividerView.snp.makeConstraints {
            $0.width.equalTo(1)
        }
        return dividerView
    }
}

extension GovernanceDelegateView {
    struct Stats: Hashable, Equatable {
        let delegationsTitle: String
        let delegations: String?
        let votesTitle: String
        let votes: String?
        let lastVotesTitle: String
        let lastVotes: String?
    }

    struct Model: Hashable {
        let addressViewModel: DisplayAddressViewModel
        let type: GovernanceDelegateTypeView.Model?
        let description: String?
        let stats: Stats?

        static func == (lhs: GovernanceDelegateView.Model, rhs: GovernanceDelegateView.Model) -> Bool {
            lhs.addressViewModel.address == rhs.addressViewModel.address &&
                lhs.addressViewModel.name == rhs.addressViewModel.name &&
                lhs.type == rhs.type &&
                lhs.description == rhs.description &&
                lhs.stats == rhs.stats
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(addressViewModel.address)
        }
    }

    func bind(viewModel: Model, locale: Locale) {
        bind(type: viewModel.type)

        typeView.locale = locale

        self.viewModel?.addressViewModel.imageViewModel?.cancel(on: avatarView.imageView)

        if let iconRadius = extractIconRadius(for: viewModel.type) {
            viewModel.addressViewModel.imageViewModel?.loadImage(
                on: avatarView.imageView,
                targetSize: Constants.iconSize,
                cornerRadius: iconRadius,
                animated: true
            )
        } else {
            viewModel.addressViewModel.imageViewModel?.loadImage(
                on: avatarView.imageView,
                targetSize: Constants.iconSize,
                animated: true
            )
        }

        nameLabel.lineBreakMode = viewModel.addressViewModel.lineBreakMode
        nameLabel.text = viewModel.addressViewModel.name ?? viewModel.addressViewModel.address

        if let description = viewModel.description {
            descriptionLabel.isHidden = false

            descriptionLabel.text = description
        } else {
            descriptionLabel.isHidden = true
        }

        if let stats = viewModel.stats {
            statsStack?.isHidden = false

            delegationsTitleLabel.text = stats.delegationsTitle
            delegationsValueLabel.text = stats.delegations
            votesTitleLabel.text = stats.votesTitle
            votesValueLabel.text = stats.votes
            lastVotesTitleLabel.text = stats.lastVotesTitle
            lastVotesValueLabel.text = stats.lastVotes
        } else {
            statsStack?.isHidden = true
        }

        self.viewModel = viewModel
    }

    private func extractIconRadius(for type: GovernanceDelegateTypeView.Model?) -> CGFloat? {
        switch type {
        case .organization:
            return nil
        case .individual, .none:
            return Constants.iconRadius
        }
    }

    private func bind(type: GovernanceDelegateTypeView.Model?) {
        switch type {
        case .organization:
            avatarView.backgroundView.apply(style: .roundedContainerWithShadow(radius: 8))
            typeStack?.isHidden = false
            typeView.bind(type: .organization)
        case .individual:
            avatarView.backgroundView.apply(style: .clear)
            typeStack?.isHidden = false
            typeView.bind(type: .individual)
        case .none:
            avatarView.backgroundView.apply(style: .clear)
            typeStack?.isHidden = true
        }
    }
}
