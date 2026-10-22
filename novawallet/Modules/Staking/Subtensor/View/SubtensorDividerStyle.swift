import UIKit

enum SubtensorDividerStyle {
    static let thickness: CGFloat = 0.5

    static func apply(to table: StackTableView) {
        table.updateLayout()
        let cells = table.stackView.arrangedSubviews.compactMap { $0 as? StackTableViewCellProtocol }
        cells.forEach { apply(to: $0, hasPrevious: false) }
        cells.filter { !$0.isHidden }.enumerated().forEach { index, cell in
            apply(to: cell, hasPrevious: index > 0)
        }
    }

    static func apply(to cell: StackTableViewCellProtocol, hasPrevious: Bool) {
        cell.borderView.borderType = hasPrevious ? .top : []
        cell.borderView.strokeWidth = thickness
        cell.borderView.strokeColor = R.color.colorDivider()!
    }
}
