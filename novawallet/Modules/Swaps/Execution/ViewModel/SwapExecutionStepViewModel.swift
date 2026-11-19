import Foundation

struct SwapExecutionStepViewModel {
    enum Status {
        case done
        case failed(details: String?, canViewTransaction: Bool)
        case notRun(number: String)
    }

    let title: String
    let status: Status
}
