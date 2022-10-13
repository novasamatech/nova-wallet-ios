import Foundation

struct StatusTimeViewModel {
    let viewModel: ReferendumInfoView.Model.Time
    let timeInterval: TimeInterval?
    let updateModelClosure: (TimeInterval) -> ReferendumInfoView.Model.Time?
}
