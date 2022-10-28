import Foundation

struct StatusTimeViewModel {
    let viewModel: ReferendumInfoView.Time
    let timeInterval: TimeInterval?
    let updateModelClosure: (TimeInterval) -> ReferendumInfoView.Time?
}
