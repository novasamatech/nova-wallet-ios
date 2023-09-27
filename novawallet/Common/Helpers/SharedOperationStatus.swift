import Foundation

enum SharedOperationStatus {
    case composing
    case sent
}

protocol SharedOperationStatusProtocol: AnyObject {
    var isComposing: Bool { get }
}

protocol SharedOperationProtocol: SharedOperationStatusProtocol {
    var status: SharedOperationStatus { get set }
}

extension SharedOperationProtocol {
    var isComposing: Bool {
        status == .composing
    }

    func markSent() {
        status = .sent
    }

    func markComposing() {
        status = .composing
    }
}

final class SharedOperation {
    var status: SharedOperationStatus = .composing
}

extension SharedOperation: SharedOperationProtocol {}
