import UIKit

final class TimelineRow: RowView<ReferendumTimelineView>, StackTableViewCellProtocol {
    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
        contentInsets = .init(top: 8, left: 16, bottom: 0, right: 16)
        backgroundColor = .clear
    }
}
