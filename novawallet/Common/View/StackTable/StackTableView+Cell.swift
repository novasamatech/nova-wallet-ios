import Foundation

extension StackTableView {
    @discardableResult
    func addTitleValueCell(for title: String, value: String) -> StackTableCell {
        let cell = StackTableCell()
        cell.titleLabel.text = title
        cell.detailsLabel.text = value

        addArrangedSubview(cell)

        return cell
    }

    @discardableResult
    func addInfoCell(for title: String, value: String) -> StackInfoTableCell {
        let cell = StackInfoTableCell()
        cell.titleLabel.text = title
        cell.detailsLabel.text = value

        addArrangedSubview(cell)

        return cell
    }

    @discardableResult
    func addLinkCell(for title: String, url: String) -> StackUrlCell {
        let cell = StackUrlCell()

        cell.titleLabel.text = title
        cell.actionButton.imageWithTitleView?.title = url

        addArrangedSubview(cell)

        return cell
    }

    @discardableResult
    func addTitleMultiValue(
        for title: String,
        valueTop: String,
        valueBottom: String
    ) -> StackTitleMultiValueCell {
        let cell = StackTitleMultiValueCell()

        cell.titleLabel.text = title
        cell.topValueLabel.text = valueTop
        cell.bottomValueLabel.text = valueBottom

        addArrangedSubview(cell)

        return cell
    }
}
