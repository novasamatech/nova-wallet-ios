import UIKit

final class LedgerAccountConfirmationViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let headerView = MultiValueView.createTableHeaderView(
        with: UIEdgeInsets(top: 0.0, left: 16, bottom: 0.0, right: 16.0)
    )

    let chainView = AssetListChainView()

    private(set) var cells: [LedgerAccountStackCell] = []

    let loadableActionButton: LoadableActionView = .create { view in
        view.actionButton.applySecondaryDefaultStyle()
    }

    let actionContainer = UIView()

    var actionButton: TriangularedButton { loadableActionButton.actionButton }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addCell() -> LedgerAccountStackCell {
        let cell = LedgerAccountStackCell()

        if let lastCell = cells.last {
            containerView.stackView.setCustomSpacing(0.0, after: lastCell)
        }

        containerView.stackView.insertArranged(view: cell, before: actionContainer)
        containerView.stackView.setCustomSpacing(16.0, after: cell)

        cells.append(cell)

        return cell
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
        }

        containerView.stackView.addArrangedSubview(headerView)
        containerView.stackView.setCustomSpacing(16.0, after: headerView)

        let chainViewContainer = UIView()
        chainViewContainer.addSubview(chainView)
        chainView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        containerView.stackView.addArrangedSubview(chainViewContainer)
        containerView.stackView.setCustomSpacing(16.0, after: chainViewContainer)

        actionContainer.addSubview(loadableActionButton)
        loadableActionButton.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        containerView.stackView.addArrangedSubview(actionContainer)
    }
}
