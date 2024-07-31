import UIKit

final class GenericLedgerAccountSelectionViewLayout: ScrollableContainerLayoutView {
    let titleLabel: UILabel = .create { label in
        label.numberOfLines = 0
        label.apply(style: .boldTitle3Primary)
    }

    private(set) var cells: [LedgerAccountStackCell] = []

    let loadMoreView: LoadableActionView = .create { view in
        view.actionButton.applySecondaryDefaultStyle()
        view.actionLoadingView.applyDisableButtonStyle()
    }

    var loadMoreButton: TriangularedButton { loadMoreView.actionButton }

    func clearCells() {
        cells.forEach { $0.removeFromSuperview() }
        cells = []
    }

    func addCell() -> LedgerAccountStackCell {
        let cell = LedgerAccountStackCell()
        cell.contentInsets = UIEdgeInsets(top: 5.0, left: 0, bottom: 5.0, right: 0)

        if let lastCell = cells.last {
            containerView.stackView.setCustomSpacing(0.0, after: lastCell)
        }

        insertArrangedSubview(cell, before: loadMoreView, spacingAfter: 16)

        cells.append(cell)

        return cell
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleLabel, spacingAfter: 16)

        addArrangedSubview(loadMoreView)
        loadMoreView.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
    }
}
