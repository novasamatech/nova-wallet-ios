import Foundation

struct SwapExecutionStepViewModel {
    enum Status {
        case done
        case failed(details: String?, fundsLocation: String?, canViewTransaction: Bool)
        case notRun(number: String)
    }

    let title: String
    let status: Status
}
