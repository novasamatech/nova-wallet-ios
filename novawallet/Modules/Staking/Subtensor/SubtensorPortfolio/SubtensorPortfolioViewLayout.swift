import UIKit
import UIKit_iOS

final class SubtensorPortfolioViewLayout: UIView {
    let backgroundView = MultigradientView.background

    let containerView: ScrollableContainerView = .create { view in
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 24, right: 16)
        view.stackView.alignment = .fill
    }

    let headerView = SubtensorPortfolioHeaderView()

    let emptyView: SubtensorPortfolioEmptyView = .create { view in
        view.isHidden = true
    }

    let syncNoticeView: InlineAlertView = {
        let view = InlineAlertView.warning()
        view.isHidden = true
        return view
    }()

    let positionsCaptionLabel = UILabel(style: .semiboldCaps1Secondary, numberOfLines: 1)

    let positionsStackView: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = 8
    }

    let bottomPanel = SubtensorBottomPanelView(style: .solid)

    let addButton: TriangularedButton = .create { button in
        button.applySecondaryDefaultStyle()
    }

    var onSelectPosition: ((Int) -> Void)?

    private var positionViews: [SubtensorPortfolioPositionView] = []
    private var skeletonViews: [SubtensorSkeletonView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorPortfolioViewModel) {
        syncNoticeView.isHidden = !viewModel.isSyncFailed

        switch viewModel.content {
        case let .positions(header, rows, loadingRows):
            headerView.isHidden = false
            emptyView.isHidden = true
            positionsCaptionLabel.isHidden = false
            positionsStackView.isHidden = false
            headerView.bind(viewModel: header)
            headerView.bind(isRatesUnavailable: viewModel.isRatesUnavailable)
            bind(rows: rows, loadingRows: loadingRows)
            addButton.applySecondaryDefaultStyle()
        case let .empty(emptyViewModel):
            headerView.isHidden = true
            emptyView.isHidden = false
            positionsCaptionLabel.isHidden = true
            positionsStackView.isHidden = true
            emptyView.bind(viewModel: emptyViewModel)
            addButton.applyDefaultStyle()
        }

        addButton.invalidateLayout()
    }
}

private extension SubtensorPortfolioViewLayout {
    enum Constants {
        static let rowHeight: CGFloat = 64
    }

    func bind(rows: [SubtensorPortfolioRowViewModel], loadingRows: Int) {
        while positionViews.count > rows.count {
            positionViews.removeLast().removeFromSuperview()
        }

        while positionViews.count < rows.count {
            let positionView = SubtensorPortfolioPositionView()
            positionView.addTarget(self, action: #selector(actionPosition(_:)), for: .touchUpInside)
            positionsStackView.insertArrangedSubview(positionView, at: positionViews.count)
            positionViews.append(positionView)
        }

        zip(positionViews, rows).forEach { positionView, row in
            positionView.bind(viewModel: row)
        }

        while skeletonViews.count > loadingRows {
            skeletonViews.removeLast().removeFromSuperview()
        }

        while skeletonViews.count < loadingRows {
            let skeletonView: SubtensorSkeletonView = .create { view in
                view.skeletonCornerRadius = 12
            }

            positionsStackView.addArrangedSubview(skeletonView)
            skeletonView.snp.makeConstraints { make in
                make.height.equalTo(Constants.rowHeight)
            }

            skeletonView.setLoading(true)
            skeletonViews.append(skeletonView)
        }
    }

    @objc func actionPosition(_ sender: SubtensorPortfolioPositionView) {
        guard let index = positionViews.firstIndex(where: { $0 === sender }) else {
            return
        }

        onSelectPosition?(index)
    }

    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(bottomPanel)
        bottomPanel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        bottomPanel.contentView.addSubview(addButton)
        addButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomPanel.snp.top)
        }

        let stackView = containerView.stackView

        stackView.addArrangedSubview(headerView)
        stackView.setCustomSpacing(20, after: headerView)

        stackView.addArrangedSubview(emptyView)
        stackView.setCustomSpacing(16, after: emptyView)

        stackView.addArrangedSubview(syncNoticeView)
        stackView.setCustomSpacing(16, after: syncNoticeView)

        stackView.addArrangedSubview(positionsCaptionLabel)
        stackView.setCustomSpacing(9, after: positionsCaptionLabel)

        stackView.addArrangedSubview(positionsStackView)
    }
}
