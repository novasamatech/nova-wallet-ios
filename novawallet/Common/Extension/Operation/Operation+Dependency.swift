import Foundation

extension Operation {
    func addDependencyIfExists(_ prevOperation: Operation?) {
        guard let prevOperation else {
            return
        }

        addDependency(prevOperation)
    }
}
