import UIKit

final class SwapOperationFeeView: UIView {
    private let tableView: StackTableView = .create { view in
        view.cellHeight = 44
        view.hasSeparators = true
        view.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 4, right: 16)
    }

    private let routeCell: SwapRouteViewCell = .create { cell in
        cell.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        cell.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        cell.rowContentView.selectable = false
    }

    private var feeCells: [StackTitleMultiValueCell] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ViewModel) {
        bindRoute(from: viewModel)
        bindFeeGroups(from: viewModel)
    }
}

private extension SwapOperationFeeView {
    func bindRoute(from viewModel: ViewModel) {
        routeCell.titleButton.setTitle(viewModel.type)
        routeCell.bind(loadableRouteViewModel: .loaded(value: viewModel.route))

        routeCell.routeView.getItems().forEach { routeItem in
            routeItem.spacing = 6
        }
    }

    func bindFeeGroups(from viewModel: ViewModel) {
        clearFeeGroups()

        viewModel.feeGroups.forEach { addFeeGroup($0) }
    }

    func clearFeeGroups() {
        feeCells.forEach { $0.removeFromSuperview() }
        feeCells = []
    }

    func addFeeGroup(_ feeGroup: FeeGroup) {
        let cells = feeGroup.amounts.map { amount in
            let feeCell = StackTitleMultiValueCell()
            feeCell.canSelect = false
            feeCell.bind(viewModel: amount)
            return feeCell
        }

        cells.first?.titleLabel.text = feeGroup.title

        feeCells.append(contentsOf: cells)

        cells.forEach { tableView.addArrangedSubview($0) }
    }

    func setupLayout() {
        addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.addArrangedSubview(routeCell)
    }
}

extension SwapOperationFeeView {
    struct FeeGroup {
        let title: String
        let amounts: [BalanceViewModelProtocol]
    }

    struct ViewModel {
        let type: String
        let route: [SwapRouteItemView.ItemViewModel]
        let feeGroups: [FeeGroup]
    }
}
