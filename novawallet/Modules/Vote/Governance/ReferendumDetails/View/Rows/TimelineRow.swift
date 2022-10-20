import UIKit

final class TimelineRow: RowView<ReferendumTimelineView> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
        roundedBackgroundView.apply(style: .roundedView)
        contentInsets = .init(top: 16, left: 16, bottom: 0, right: 16)
        backgroundColor = .clear
    }
}
