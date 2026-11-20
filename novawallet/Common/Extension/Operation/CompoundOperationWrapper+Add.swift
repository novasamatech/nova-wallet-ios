import Foundation
import Operation_iOS

extension CompoundOperationWrapper {
    func insertingHeadIfExists(operations: [Operation]?) -> CompoundOperationWrapper {
        guard let operations else {
            return self
        }

        return insertingHead(operations: operations)
    }
}
