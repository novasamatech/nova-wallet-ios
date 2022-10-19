import UIKit

final class ReferendumDAppCellView: RowView<ReferendumDAppView>, StackTableViewCellProtocol {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        preferredHeight = 64
    }
}
