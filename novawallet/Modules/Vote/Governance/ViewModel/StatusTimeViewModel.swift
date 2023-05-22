import Foundation

struct StatusTimeViewModel: Equatable {
    let viewModel: ReferendumInfoView.Time
    let timeInterval: TimeInterval?
    let updateModelClosure: (TimeInterval) -> ReferendumInfoView.Time?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.viewModel.titleIcon.title == rhs.viewModel.titleIcon.title && lhs.timeInterval == rhs.timeInterval
    }
}
