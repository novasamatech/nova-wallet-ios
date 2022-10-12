import Foundation

struct StatusTimeModel {
    let viewModel: ReferendumInfoView.Model.Time
    let timeInterval: TimeInterval?
    let updateModelClosure: (TimeInterval) -> ReferendumInfoView.Model.Time?
}
