import UIKit

final class ReferendumDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 24, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let titleView = ReferendumDetailsTitleView()
    let votingDetailsView = BlurredView<ReferendumVotingStatusDetailsView>()
    let dAppsTableView = StackTableView()
    let timelineTableView: BlurredView<ReferendumTimelineView> = .create {
        $0.innerInsets = .init(top: 16, left: 16, bottom: 20, right: 16)
    }

    let fullDetailsView = FullDetailsRow(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        containerView.stackView.spacing = 12
        containerView.stackView.addArrangedSubview(titleView)
        containerView.stackView.setCustomSpacing(16, after: titleView)

        containerView.stackView.addArrangedSubview(votingDetailsView)
        containerView.stackView.addArrangedSubview(dAppsTableView)
        containerView.stackView.addArrangedSubview(timelineTableView)
        containerView.stackView.addArrangedSubview(fullDetailsView)
    }

    func setDApps(models: [ReferendumDAppView.Model]) {
        for model in models {
            let dAppView = ReferendumDAppCellView(frame: .zero)
            dAppView.rowContentView.bind(viewModel: model)
            dAppsTableView.stackView.addArrangedSubview(dAppView)
        }
    }
}

final class ReferendumDAppCellView: RowView<ReferendumDAppView>, StackTableViewCellProtocol {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        preferredHeight = 64
    }
}

final class FullDetailsRow: RowView<BlurredView<GenericTitleValueView<UILabel, UIImageView>>> {
    let titleLabel = UILabel(style: .rowLink, textAlignment: .left)
    let arrowView = UIImageView(image: R.image.iconChevronRight())

    override init(frame _: CGRect) {
        super.init(
            contentView: .init(view: .init(titleView: titleLabel, valueView: arrowView)),
            preferredHeight: 52
        )
        backgroundColor = .clear
    }

    func bind(title: String) {
        titleLabel.text = title
    }
}

extension UILabel.Style {
    static let rowLink = UILabel.Style(
        textColor: R.color.colorAccent(),
        font: .p2Paragraph
    )
}
