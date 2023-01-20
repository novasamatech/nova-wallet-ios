import UIKit
import SoraUI

final class DelegateView: UIView {
    let nameLabel = UILabel(style: .regularSubhedlinePrimary)
    let typeView: BorderedIconLabelView = .create {
        $0.iconDetailsView.spacing = 6
        $0.contentInsets = .init(top: 1, left: 4, bottom: 1, right: 6)
        $0.iconDetailsView.detailsLabel.numberOfLines = 1
    }

    let descriptionLabel = UILabel(style: .footnoteSecondary)
    let delegationsTitleLabel = UILabel(style: .caption2Secondary)
    let delegationsValueLabel = UILabel(style: .footnotePrimary)
    let votesTitleLabel = UILabel(style: .caption2Secondary)
    let votesValueLabel = UILabel(style: .footnotePrimary)
    let lastVotesTitleLabel = UILabel(style: .caption2Secondary)
    let lastVotesValueLabel = UILabel(style: .footnotePrimary)
    private var viewModel: Model?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    let avatarView: DAppIconView = .create {
        $0.contentInsets = .zero
    }

    private func setupLayout() {
        let lastVotes = UIView.vStack([
            lastVotesTitleLabel,
            lastVotesValueLabel
        ])
        lastVotes.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let contentView = UIView.vStack(spacing: 16, [
            .hStack(alignment: .center, spacing: 12, [
                avatarView,
                .vStack(spacing: 4, [
                    nameLabel,
                    .hStack([
                        typeView,
                        UIView()
                    ])
                ])
            ]),
            descriptionLabel,
            .hStack(spacing: 12, [
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
                lastVotes
            ])
        ])

        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        avatarView.snp.makeConstraints {
            $0.size.equalTo(CGSize(width: 40, height: 40))
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

extension DelegateView {
    struct Model: Hashable {
        let id: String
        let icon: ImageViewModelProtocol?
        let name: String
        let type: DelegateType?
        let description: String?
        let delegationsTitle: String
        let delegations: String?
        let votesTitle: String
        let votes: String?
        let lastVotesTitle: String
        let lastVotes: String?

        static func == (lhs: DelegateView.Model, rhs: DelegateView.Model) -> Bool {
            lhs.id == rhs.id &&
                lhs.name == rhs.name &&
                lhs.type == rhs.type &&
                lhs.description == rhs.description &&
                lhs.delegations == rhs.delegations &&
                lhs.delegationsTitle == rhs.delegationsTitle &&
                lhs.votes == rhs.votes &&
                lhs.votesTitle == rhs.votesTitle &&
                lhs.lastVotes == rhs.lastVotes &&
                lhs.lastVotesTitle == rhs.lastVotesTitle
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    enum DelegateType {
        case organization
        case individual
    }

    func bind(viewModel: Model, locale: Locale) {
        bind(type: viewModel.type, locale: locale)

        self.viewModel?.icon?.cancel(on: avatarView.imageView)
        viewModel.icon?.loadImage(
            on: avatarView.imageView,
            targetSize: .init(width: 40, height: 40),
            animated: true
        )
        nameLabel.text = viewModel.name
        descriptionLabel.text = viewModel.description
        delegationsTitleLabel.text = viewModel.delegationsTitle
        delegationsValueLabel.text = viewModel.delegations
        votesTitleLabel.text = viewModel.votesTitle
        votesValueLabel.text = viewModel.votes
        lastVotesTitleLabel.text = viewModel.lastVotesTitle
        lastVotesValueLabel.text = viewModel.lastVotes
        self.viewModel = viewModel
    }

    private func bind(type: DelegateType?, locale: Locale) {
        switch type {
        case .organization:
            avatarView.backgroundView.apply(style: .roundedContainer(radius: 8))
            typeView.apply(style: .organization)
            typeView.isHidden = false
            let title = R.string.localizable.delegationsShowChipOrganization(preferredLanguages: locale.rLanguages).uppercased()
            typeView.iconDetailsView.bind(viewModel: .init(
                title: title,
                icon: R.image.iconOrganization()
            ))
        case .individual:
            avatarView.backgroundView.apply(style: .rounded(radius: 20))
            typeView.apply(style: .individual)
            typeView.isHidden = false
            let title = R.string.localizable.delegationsShowChipIndividual(preferredLanguages: locale.rLanguages).uppercased()
            typeView.iconDetailsView.bind(viewModel: .init(
                title: title,
                icon: R.image.iconIndividual()
            ))
        case .none:
            avatarView.backgroundView.apply(style: .rounded(radius: 0))
            typeView.isHidden = true
            typeView.iconDetailsView.bind(viewModel: .init(
                title: "",
                icon: nil
            ))
        }
    }
}
