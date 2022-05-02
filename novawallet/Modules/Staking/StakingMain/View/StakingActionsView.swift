import UIKit

protocol StakingActionsViewDelegate: AnyObject {
    func actionsViewDidSelectAction(_ action: StakingManageOption)
}

final class StakingActionsView: UIView {
    weak var delegate: StakingActionsViewDelegate?

    let backgroundView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.sideLength = 12.0
        return view
    }()

    let tableView: StackTableView = {
        let view = StackTableView()
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.hasSeparators = false
        view.contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 8.0, right: 16.0)
        view.cornerRadius = 12.0
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    private var cells: [StackActionCell] = []
    private var actions: [StakingManageOption] = []

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                applyActions()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }

        addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }
    }

    func bind(actions: [StakingManageOption]) {
        if actions.count > self.actions.count {
            let newCellsCount = actions.count - self.actions.count
            let newCells: [StackActionCell] = (0 ..< newCellsCount).map { _ in
                let cell = StackActionCell()
                cell.addTarget(self, action: #selector(actionCell(on:)), for: .touchUpInside)

                return cell
            }

            newCells.forEach { tableView.addArrangedSubview($0) }
            cells.append(contentsOf: newCells)
        } else if actions.count < self.actions.count {
            let dropCellsCount = self.actions.count - actions.count

            let dropCells = cells.suffix(dropCellsCount)
            dropCells.forEach { $0.removeFromSuperview() }

            cells = Array(cells.prefix(actions.count))
        }

        self.actions = actions

        applyActions()
    }

    private func applyActions() {
        for (action, cell) in zip(actions, cells) {
            let title = action.titleForLocale(locale)
            let icon = action.icon?.tinted(with: R.color.colorWhite48()!)
            let details = action.detailsForLocale(locale)

            cell.bind(title: title, icon: icon, details: details)
        }
    }

    @objc func actionCell(on sender: UIControl) {
        guard let cell = sender as? StackActionCell, let index = cells.firstIndex(of: cell) else {
            return
        }

        delegate?.actionsViewDidSelectAction(actions[index])
    }
}
