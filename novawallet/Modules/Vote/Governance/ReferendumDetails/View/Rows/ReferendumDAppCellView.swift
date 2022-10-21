import UIKit

final class ReferendumDAppCellView: RowView<ReferendumDAppView>, StackTableViewCellProtocol {
    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        preferredHeight = 64
        contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
    }
}
