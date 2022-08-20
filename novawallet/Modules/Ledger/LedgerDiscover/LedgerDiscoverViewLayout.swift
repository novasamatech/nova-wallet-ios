import UIKit

final class LedgerDiscoverViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 12.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let headerView = MultiValueView.createTableHeaderView()

    let activityIndicator: UIActivityIndicatorView = .create { view in
        view.style = .medium
        view.tintColor = R.color.colorWhite()
        view.hidesWhenStopped = true
    }

    private(set) var cells: [LoadableStackActionCell<UILabel>] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    func clearCells() {
        for cell in cells {
            cell.removeFromSuperview()
        }

        cells = []
    }

    func addCell(for name: String) -> LoadableStackActionCell<UILabel> {
        let cell = LoadableStackActionCell<UILabel>.createSingleCell()
        cell.applyDefaultTitleStyle()

        cell.rowContentView.titleView.text = name

        containerView.stackView.addArrangedSubview(cell)
        containerView.stackView.setCustomSpacing(12.0, after: cell)

        cells.append(cell)

        return cell
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
        }

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalTo(containerView.snp.center)
        }

        containerView.stackView.addArrangedSubview(headerView)

        containerView.stackView.setCustomSpacing(24.0, after: headerView)
    }
}
