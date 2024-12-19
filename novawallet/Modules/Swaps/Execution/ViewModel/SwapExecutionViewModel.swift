import Foundation

enum SwapExecutionViewModel {
    struct InProgress {
        let remainedTimeViewModel: CountdownLoadingView.ViewModel
        let currentOperation: String
        let details: String
    }

    struct Completed {
        let time: String
        let details: String
    }

    struct Failed {
        let time: String
        let details: String
    }

    case inProgress(InProgress)
    case completed(Completed)
    case failed(Failed)
}
