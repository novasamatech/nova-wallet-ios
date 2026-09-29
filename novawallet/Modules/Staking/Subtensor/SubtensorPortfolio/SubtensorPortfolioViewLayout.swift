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

    let syncNoticeControl: UIControl = .create { view in
        view.backgroundColor = R.color.colorBlockBackground()
        view.layer.cornerRadius = 12
        view.isHidden = true
    }

    let syncNoticeLabel: UILabel = .create { label in
        label.apply(style: .footnotePrimary)
        label.textAlignment = .center
        label.numberOfLines = 0
    }

    let positionsCaptionLabel: UILabel = .create { label in
        label.apply(style: .semiboldCaps2Secondary)
    }

    let positionsStackView: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = 8
    }

    let bottomBar: UIView = .create { view in
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    let addButton: TriangularedButton = .create { button in
        button.applySecondaryDefaultStyle()
    }

    var onSelectPosition: ((Int) -> Void)?

    private var positionViews: [SubtensorPortfolioPositionView] = []
    private let skeletonViews: [SubtensorChartLoadingView] = (0 ..< 2).map { _ in SubtensorChartLoadingView() }

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
        syncNoticeControl.isHidden = !viewModel.isSyncFailed

        switch viewModel.content {
        case let .positions(header, rows):
            headerView.isHidden = false
            emptyView.isHidden = true
            positionsCaptionLabel.isHidden = false
            positionsStackView.isHidden = false
            headerView.bind(viewModel: header)
            bind(rows: rows)
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
        static let buttonHeight: CGFloat = 52
        static let rowHeight: CGFloat = 64
    }

    func bind(rows: [SubtensorPortfolioRowViewModel]?) {
        skeletonViews.forEach { $0.setLoading(rows == nil) }

        let rows = rows ?? []

        while positionViews.count > rows.count {
            positionViews.removeLast().removeFromSuperview()
        }

        while positionViews.count < rows.count {
            let positionView = SubtensorPortfolioPositionView()
            positionView.addTarget(self, action: #selector(actionPosition(_:)), for: .touchUpInside)
            positionsStackView.addArrangedSubview(positionView)
            positionViews.append(positionView)
        }

        zip(positionViews, rows).forEach { positionView, row in
            positionView.bind(viewModel: row)
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

        addSubview(bottomBar)
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        bottomBar.addSubview(addButton)
        addButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(16)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(12)
            make.height.equalTo(Constants.buttonHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }

        let stackView = containerView.stackView

        stackView.addArrangedSubview(headerView)
        stackView.setCustomSpacing(16, after: headerView)

        stackView.addArrangedSubview(emptyView)
        stackView.setCustomSpacing(16, after: emptyView)

        syncNoticeControl.addSubview(syncNoticeLabel)
        syncNoticeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }

        stackView.addArrangedSubview(syncNoticeControl)
        stackView.setCustomSpacing(16, after: syncNoticeControl)

        stackView.addArrangedSubview(positionsCaptionLabel)
        stackView.setCustomSpacing(8, after: positionsCaptionLabel)

        stackView.addArrangedSubview(positionsStackView)

        skeletonViews.forEach { view in
            positionsStackView.addArrangedSubview(view)
            view.snp.makeConstraints { make in
                make.height.equalTo(Constants.rowHeight)
            }
        }
    }
}
