import UIKit

final class DAppItemTableViewCell: PlainBaseTableViewCell<DAppItemView> {
    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(
            style: style,
            reuseIdentifier: reuseIdentifier
        )

        backgroundColor = .clear

        let selectedView = UIView()
        selectedView.backgroundColor = R.color.colorCellBackgroundPressed()
        selectedBackgroundView = selectedView
    }
}
