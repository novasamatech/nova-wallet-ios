import UIKit

final class DAppItemCollectionViewCell: CollectionViewContainerCell<DAppItemView> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        let selectedView = UIView()
        selectedView.backgroundColor = R.color.colorCellBackgroundPressed()
        selectedBackgroundView = selectedView
    }
}
