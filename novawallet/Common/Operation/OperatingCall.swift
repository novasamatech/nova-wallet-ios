import Foundation
import RobinHood

protocol OperatingCall: CancellableCall {
    var allOperations: [Operation] { get }
}

extension BaseOperation: OperatingCall {
    var allOperations: [Operation] {
        [self]
    }
}

extension CompoundOperationWrapper: OperatingCall {}
