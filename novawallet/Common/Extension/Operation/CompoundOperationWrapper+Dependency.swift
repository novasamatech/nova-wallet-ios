import Foundation
import Operation_iOS

extension CompoundOperationWrapper {
    func addDependencyIfExists(operations: [Operation]?) {
        guard let operations else {
            return
        }

        addDependency(operations: operations)
    }

    func addDependencyIfExists<T>(wrapper: CompoundOperationWrapper<T>?) {
        guard let wrapper else {
            return
        }

        addDependency(wrapper: wrapper)
    }
}
