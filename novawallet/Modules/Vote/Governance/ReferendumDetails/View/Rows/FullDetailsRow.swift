import UIKit
import UIKit_iOS

final class FullDetailsRow: RowView<GenericTitleValueView<UILabel, UIImageView>> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        rowContentView.titleView.apply(style: .rowLink)
        rowContentView.titleView.textAlignment = .left
        rowContentView.valueView.image = R.image.iconChevronRight()
        roundedBackgroundView.apply(style: .roundedLightCell)
        preferredHeight = 52
        contentInsets = .init(top: 14, left: 16, bottom: 14, right: 16)
        borderView.borderType = .none
    }

    func bind(title: String) {
        rowContentView.titleView.text = title
    }
}
