import UIKit
import UIKit_iOS

class GovernanceSelectTracksViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        view.stackView.alignment = .center
        return view
    }()

    let titleLabel: UILabel = .create {
        $0.apply(style: .secondaryScreenTitle)
        $0.numberOfLines = 0
    }

    let tracksGroupContainerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .horizontal)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        view.stackView.spacing = 8.0
        view.scrollView.showsHorizontalScrollIndicator = false
        return view
    }()

    private(set) var emptyStateView: EmptyStateView?

    private(set) var proceedButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        contentView.stackView.setCustomSpacing(16, after: titleLabel)

        contentView.stackView.addArrangedSubview(tracksGroupContainerView)
        tracksGroupContainerView.snp.makeConstraints { make in
            make.height.equalTo(32.0)
            make.width.equalTo(self)
        }

        contentView.stackView.setCustomSpacing(12, after: tracksGroupContainerView)

        addSubview(proceedButton)

        proceedButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        contentView.scrollView.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.actionHeight + 2 * UIConstants.actionBottomInset,
            right: 0
        )
    }

    func clearGroupButtons(_ buttons: [RoundedButton]) {
        buttons.forEach { $0.removeFromSuperview() }
    }

    func addGroupButton(for title: String) -> RoundedButton {
        let groupButton = createGroupButton(for: title)

        tracksGroupContainerView.stackView.addArrangedSubview(groupButton)

        return groupButton
    }

    func clearTrackRows(_ trackRows: [RowView<GovernanceSelectableTrackView>]) {
        trackRows.forEach { $0.removeFromSuperview() }
    }

    func addTrackRow(
        for viewModel: SelectableViewModel<ReferendumInfoView.Track>
    ) -> RowView<GovernanceSelectableTrackView> {
        let trackRow = createTrackRow(for: viewModel)

        contentView.stackView.addArrangedSubview(trackRow)

        trackRow.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        return trackRow
    }

    func clearEmptyStateView() {
        emptyStateView?.removeFromSuperview()
        emptyStateView = nil
    }

    func addEmptyStateView() {
        let emptyStateView = createEmptyStateView()

        contentView.stackView.addArrangedSubview(emptyStateView)

        emptyStateView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-32)
            make.height.equalTo(self).offset(-275)
        }

        self.emptyStateView = emptyStateView
    }

    func setGroupsContainer(hidden: Bool) {
        tracksGroupContainerView.isHidden = hidden
    }

    private func createTrackRow(
        for viewModel: SelectableViewModel<ReferendumInfoView.Track>
    ) -> RowView<GovernanceSelectableTrackView> {
        let rowView = RowView(contentView: GovernanceSelectableTrackView(), preferredHeight: 44)
        rowView.roundedBackgroundView.highlightedFillColor = .clear
        rowView.rowContentView.bind(viewModel: viewModel)
        rowView.contentInsets = .zero
        rowView.borderView.borderType = []
        return rowView
    }

    private func createGroupButton(for title: String) -> RoundedButton {
        let button = RoundedButton()
        button.applyAccessoryStyle()

        button.contentInsets = UIEdgeInsets(top: 6.0, left: 8.0, bottom: 6.0, right: 8.0)
        button.imageWithTitleView?.title = title

        return button
    }

    private func createEmptyStateView() -> EmptyStateView {
        let view = EmptyStateView()

        view.image = R.image.iconHistoryEmptyDark()
        view.verticalSpacing = 0
        view.titleColor = R.color.colorTextSecondary()!
        view.titleFont = .regularFootnote

        return view
    }
}
