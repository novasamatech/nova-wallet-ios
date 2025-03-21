import Foundation
import Operation_iOS

enum OperationCombiningServiceError: Error {
    case alreadyRunningOrFinished
    case noResult
}

final class OperationCombiningService<T>: Longrunable {
    enum State {
        case waiting
        case running
        case finished
    }

    typealias ResultType = [T]

    let operationsClosure: () throws -> [CompoundOperationWrapper<T>]
    let operationManager: OperationManagerProtocol
    let operationsPerBatch: Int

    private(set) var state: State = .waiting

    private var wrappers: [CompoundOperationWrapper<T>]?

    init(
        operationManager: OperationManagerProtocol,
        operationsPerBatch: Int = 0,
        operationsClosure: @escaping () throws -> [CompoundOperationWrapper<T>]
    ) {
        self.operationManager = operationManager
        self.operationsClosure = operationsClosure
        self.operationsPerBatch = operationsPerBatch
    }

    func start(with completionClosure: @escaping (Result<ResultType, Error>) -> Void) {
        guard state == .waiting else {
            completionClosure(.failure(OperationCombiningServiceError.alreadyRunningOrFinished))
            return
        }

        state = .waiting

        do {
            let wrappers = try operationsClosure()

            if operationsPerBatch > 0, wrappers.count > operationsPerBatch {
                for index in operationsPerBatch ..< wrappers.count {
                    let prevBatchIndex = index / operationsPerBatch - 1

                    let prevStart = prevBatchIndex * operationsPerBatch
                    let prevEnd = (prevBatchIndex + 1) * operationsPerBatch

                    for prevIndex in prevStart ..< prevEnd {
                        wrappers[index].addDependency(wrapper: wrappers[prevIndex])
                    }
                }
            }

            let mapOperation = ClosureOperation<ResultType> {
                try wrappers.map { try $0.targetOperation.extractNoCancellableResultData() }
            }

            mapOperation.completionBlock = { [weak self] in
                self?.state = .finished
                self?.wrappers = nil

                do {
                    let result = try mapOperation.extractNoCancellableResultData()
                    completionClosure(.success(result))
                } catch {
                    completionClosure(.failure(error))
                }
            }

            let dependencies = wrappers.flatMap(\.allOperations)
            dependencies.forEach { mapOperation.addDependency($0) }

            operationManager.enqueue(operations: dependencies + [mapOperation], in: .transient)

        } catch {
            completionClosure(.failure(error))
        }
    }

    func cancel() {
        if state == .running {
            wrappers?.forEach { $0.cancel() }
            wrappers = nil
        }

        state = .finished
    }
}

extension OperationCombiningService {
    func longrunOperation() -> LongrunOperation<[T]> {
        LongrunOperation(longrun: AnyLongrun(longrun: self))
    }

    static func compoundWrapper(
        operationManager: OperationManagerProtocol,
        wrapperClosure: @escaping () throws -> CompoundOperationWrapper<T>?
    ) -> CompoundOperationWrapper<T?> {
        let loadingOperation: BaseOperation<[T]> = OperationCombiningService(operationManager: operationManager) {
            if let wrapper = try wrapperClosure() {
                return [wrapper]
            } else {
                return []
            }
        }.longrunOperation()

        let mappingOperation = ClosureOperation<T?> {
            try loadingOperation.extractNoCancellableResultData().first
        }

        mappingOperation.addDependency(loadingOperation)

        return .init(targetOperation: mappingOperation, dependencies: [loadingOperation])
    }

    static func compoundOptionalWrapper(
        operationManager: OperationManagerProtocol,
        wrapperClosure: @escaping () throws -> CompoundOperationWrapper<T?>?
    ) -> CompoundOperationWrapper<T?> {
        let loadingOperation: BaseOperation<[T?]> = OperationCombiningService<T?>(operationManager: operationManager) {
            if let wrapper = try wrapperClosure() {
                return [wrapper]
            } else {
                return []
            }
        }.longrunOperation()

        let mappingOperation = ClosureOperation<T?> {
            let results = try loadingOperation.extractNoCancellableResultData()

            if !results.isEmpty {
                return results[0]
            } else {
                return nil
            }
        }

        mappingOperation.addDependency(loadingOperation)

        return .init(targetOperation: mappingOperation, dependencies: [loadingOperation])
    }

    static func compoundNonOptionalWrapper(
        operationManager: OperationManagerProtocol,
        wrapperClosure: @escaping () throws -> CompoundOperationWrapper<T>
    ) -> CompoundOperationWrapper<T> {
        let loadingOperation: BaseOperation<[T]> = OperationCombiningService<T>(operationManager: operationManager) {
            let wrapper = try wrapperClosure()
            return [wrapper]
        }.longrunOperation()

        let mappingOperation = ClosureOperation<T> {
            guard let result = try loadingOperation.extractNoCancellableResultData().first else {
                throw OperationCombiningServiceError.noResult
            }

            return result
        }

        mappingOperation.addDependency(loadingOperation)

        return .init(targetOperation: mappingOperation, dependencies: [loadingOperation])
    }

    static func compoundNonOptionalWrapper(
        operationQueue: OperationQueue,
        wrapperClosure: @escaping () throws -> CompoundOperationWrapper<T>
    ) -> CompoundOperationWrapper<T> {
        compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue),
            wrapperClosure: wrapperClosure
        )
    }
}
