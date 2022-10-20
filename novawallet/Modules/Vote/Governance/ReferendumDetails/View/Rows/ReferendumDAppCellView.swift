import UIKit

final class ReferendumDAppCellView: RowView<ReferendumDAppView>, StackTableViewCellProtocol {
    override init(frame: CGRect) {
        super.init(frame: frame)

        roundedBackgroundView.apply(style: .roundedSelectableCell)
        backgroundColor = .clear
        preferredHeight = 64
    }
}
