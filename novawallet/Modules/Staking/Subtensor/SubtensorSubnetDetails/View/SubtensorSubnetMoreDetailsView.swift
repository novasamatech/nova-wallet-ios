import UIKit

final class SubtensorSubnetMoreDetailsView: CollapsableContainerView {
    let numberCell: StackTableCell = .create { cell in
        cell.isUserInteractionEnabled = false
        cell.contentInsets = .zero
        cell.borderView.borderType = .top
        cell.borderView.strokeColor = R.color.colorDivider()!
    }

    override var rows: [UIView] {
        [numberCell]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentInsets = .zero
        backgroundView.isHidden = true
        titleControl.titleLabel.apply(style: .regularSubhedlineSecondary)

        setExpanded(false, animated: false)
    }
}
