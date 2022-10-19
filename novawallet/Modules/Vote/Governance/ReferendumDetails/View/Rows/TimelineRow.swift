import UIKit

final class TimelineRow: RowView<ReferendumTimelineView> {
    let referendumTimelineView = ReferendumTimelineView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView = referendumTimelineView
        backgroundView = TriangularedBlurView()
        contentInsets = .init(top: 16, left: 16, bottom: 0, right: 16)
        backgroundColor = .clear
    }
}
