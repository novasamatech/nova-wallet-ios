import UIKit

final class InAppUpdatesViewLayout: UIView {
    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.separatorStyle = .none
        view.backgroundColor = .clear
        view.contentInset = .zero
        view.rowHeight = UITableView.automaticDimension
        view.allowsSelection = false
        view.showsVerticalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.tableHeaderView = .init(frame: .init(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        view.sectionHeaderHeight = 0
        view.sectionFooterHeight = 0
        loadMoreFooter.frame = .init(origin: .zero, size: loadMoreFooter.intrinsicContentSize)
        view.tableFooterView = loadMoreFooter
        view.registerClassForCell(VersionTableViewCell.self)
        view.registerClassForCell(GradientBannerTableViewCell.self)
        return view
    }()

    let loadMoreFooter = LoadMoreFooterView()

    let installButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top).inset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        addSubview(installButton)
        installButton.snp.makeConstraints {
            $0.top.equalTo(tableView.snp.bottom)
            $0.height.equalTo(52)
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalTo(safeAreaLayoutGuide).inset(16)
        }
    }
}
