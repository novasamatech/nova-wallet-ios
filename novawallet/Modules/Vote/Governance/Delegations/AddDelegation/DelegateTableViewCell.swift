import UIKit
import SoraUI

final class DelegateTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    let avatarView = RoundedView()
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
    let contentInsets = UIEdgeInsets(
        top: 12,
        left: 12,
        bottom: 12,
        right: 12
    )
    var locale: Locale?

    private func setupLayout() {
        let contentView = UIView.vStack(spacing: 16, [
            .hStack(alignment: .center, spacing: 12, [
                avatarView,
                .vStack(spacing: 4, [
                    nameLabel,
                    typeView
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
                .vStack([
                    lastVotesTitleLabel,
                    lastVotesValueLabel
                ])
            ])
        ])

        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
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

extension DelegateTableViewCell {
    struct Model: Hashable {
        static func == (lhs: DelegateTableViewCell.Model, rhs: DelegateTableViewCell.Model) -> Bool {
            lhs.id == rhs.id &&
                lhs.name == rhs.name &&
                lhs.type == rhs.type &&
                lhs.description == rhs.description &&
                lhs.delegations == rhs.delegations &&
                lhs.votes == rhs.votes &&
                lhs.lastVotes == rhs.lastVotes
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        let id: String
        let icon: ImageViewModelProtocol?
        let name: String
        let type: DelegateType?
        let description: String?
        let delegations: String?
        let votes: String?
        let lastVotes: String?
    }

    enum DelegateType {
        case organization
        case individual
    }

    func bind(viewModel: Model) {
        switch viewModel.type {
        case .organization:
            avatarView.apply(style: .roundedContainer(radius: 8))
            typeView.apply(style: .organization)
            typeView.isHidden = false
            typeView.iconDetailsView.bind(viewModel: .init(
                title: "organization".uppercased(),
                icon: R.image.iconOrganization()
            ))
        case .individual:
            avatarView.apply(style: .rounded(radius: 20))
            typeView.apply(style: .individual)
            typeView.isHidden = false
            typeView.iconDetailsView.bind(viewModel: .init(
                title: "individual".uppercased(),
                icon: R.image.iconIndividual()
            ))
        case .none:
            avatarView.apply(style: .rounded(radius: 0))
            typeView.isHidden = true
            typeView.iconDetailsView.bind(viewModel: .init(
                title: "",
                icon: nil
            ))
        }

        descriptionLabel.text = viewModel.description
        delegationsTitleLabel.text = "Delegations"
        delegationsValueLabel.text = viewModel.delegations
        votesTitleLabel.text = "Delegated votes"
        votesValueLabel.text = viewModel.votes
        lastVotesTitleLabel.text = "Voted last 30 days"
        lastVotesValueLabel.text = viewModel.lastVotes
    }
}

extension DelegateTableViewCell {}

extension BorderedIconLabelView {
    struct Style {
        let text: UILabel.Style
        let background: RoundedView.Style
    }

    func apply(style: Style) {
        iconDetailsView.detailsLabel.apply(style: style.text)
        backgroundView.apply(style: style.background)
    }
}

extension BorderedIconLabelView.Style {
    static let organization = BorderedIconLabelView.Style(
        text: .init(
            textColor: R.color.colorOrganizationChipText()!,
            font: .semiBoldSmall
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorOrganizationChipText()!,
            highlightedFillColor: R.color.colorOrganizationChipText()!
        )
    )
    static let individual = BorderedIconLabelView.Style(
        text: .init(
            textColor: R.color.colorIndividualChipText()!,
            font: .semiBoldSmall
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorIndividualChipText()!,
            highlightedFillColor: R.color.colorIndividualChipText()!
        )
    )
}
