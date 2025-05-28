import UIKit

final class GenericLedgerAccountSelectionViewLayout: ScrollableContainerLayoutView {
    let titleLabel: UILabel = .create { label in
        label.numberOfLines = 0
        label.apply(style: .boldTitle3Primary)
    }

    private(set) var sections: [StackTableView] = []

    let loadMoreView: LoadableActionView = .create { view in
        view.actionButton.applySecondaryDefaultStyle()
        view.actionLoadingView.applyDisableButtonStyle()
    }

    var loadMoreButton: TriangularedButton { loadMoreView.actionButton }

    func clearSections() {
        sections.forEach { $0.removeFromSuperview() }
        sections = []
    }

    func addAccountSection() -> StackTableView {
        let section = StackTableView()
        section.contentInsets = UIEdgeInsets(top: 6, left: 16, bottom: 0, right: 16)
        section.cellHeight = 44

        if let lastSection = sections.last {
            containerView.stackView.setCustomSpacing(8.0, after: lastSection)
        }

        insertArrangedSubview(section, before: loadMoreView, spacingAfter: 16)

        sections.append(section)

        return section
    }

    func addAccountHeader(to section: StackTableView) -> GenericLedgerAccountStackCell {
        let headerCell = GenericLedgerAccountStackCell()

        section.addArrangedSubview(headerCell)

        section.setCustomHeight(52, at: 0)
        section.setShowsSeparator(false, at: 0)

        return headerCell
    }

    func addAddressCell(to section: StackTableView) -> GenericLedgerAddressStackCell {
        let addressCell = GenericLedgerAddressStackCell()

        section.addArrangedSubview(addressCell)

        return addressCell
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
