import Foundation
import Operation_iOS

// A mirror of the app's operation helpers, carried here because Operation-iOS 2.1.2 — the
// version the app pins, and therefore the version every package built beside it must pin —
// predates `OperationCombiningService`, the `Longrun` primitives and the
// `CompoundOperationWrapper` conveniences below. The app declares its own copies for exactly
// that reason, and the code moved into `NovaAppAttest` (and, next, `NovaAnalytics`) was
// written against them, so those packages need the same pieces to compile at all.
//
// It mirrors six app files:
//
//   novawallet/Common/Operation/OperationCombiningService.swift
//   novawallet/Common/Operation/Longrun/Longrun.swift
//   novawallet/Common/Operation/Longrun/LongrunOperation.swift
//   novawallet/Common/Extension/Operation/CompoundOperationWrapper+Result.swift
//   novawallet/Common/Extension/Operation/CompoundOperationWrapper+Dependency.swift
//   novawallet/Common/Extension/Operation/CompoundOperationWrapper+Add.swift
//
// THE RULE, because a mirror that has been edited cannot be diffed against its source:
// every member present is byte-identical to its app original; members this package does not
// use are absent entirely. Nothing here is pruned, repaired, renamed or reordered within a
// member it does carry — so `operationsPerBatch` and its batching block stay even though no
// caller here passes a batch size, and `State.running` stays even though nothing assigns it.
// The two permitted deviations are access modifiers, which the module boundary forces, and
// comments, which no diff of behaviour reads.
//
// Members left out because nothing here calls them: `addDependencyIfExists`,
// `insertingHeadIfExists`, `compoundWrapper` and `compoundOptionalWrapper`.
//
// Delete this file — and this package — when the Operation-iOS pin moves to a release that
// ships these; the SDK versions are identical in behaviour, only `public`.

// MARK: - CompoundOperationWrapper+Result

public extension CompoundOperationWrapper {
    static func createWithError(_ error: Error) -> CompoundOperationWrapper<ResultType> {
        let operation = BaseOperation<ResultType>()
        operation.result = .failure(error)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    static func createWithResult(_ result: ResultType) -> CompoundOperationWrapper<ResultType> {
        let operation = BaseOperation<ResultType>()
        operation.result = .success(result)
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

// MARK: - CompoundOperationWrapper+Dependency

public extension CompoundOperationWrapper {
    func addDependency(operations: [Operation]) {
        allOperations.forEach { nextOperation in
            operations.forEach { prevOperation in
                nextOperation.addDependency(prevOperation)
            }
        }
    }

    func addDependency<T>(wrapper: CompoundOperationWrapper<T>) {
        addDependency(operations: wrapper.allOperations)
    }
}

// MARK: - CompoundOperationWrapper+Add

public extension CompoundOperationWrapper {
    func insertingHead(operations: [Operation]) -> CompoundOperationWrapper {
        .init(targetOperation: targetOperation, dependencies: operations + dependencies)
    }

    func insertingTail<T>(operation: BaseOperation<T>) -> CompoundOperationWrapper<T> {
        .init(targetOperation: operation, dependencies: allOperations)
    }
}

// MARK: - Longrun

protocol Longrunable {
    associatedtype ResultType

    func start(with completionClosure: @escaping (Result<ResultType, Error>) -> Void)
    func cancel()
}

final class AnyLongrun<T>: Longrunable {
    typealias ResultType = T

    private let privateStart: (@escaping (Result<ResultType, Error>) -> Void) -> Void
    private let privateCancel: () -> Void

    init<U: Longrunable>(longrun: U) where U.ResultType == ResultType {
        privateStart = longrun.start
        privateCancel = longrun.cancel
    }

    func start(with completionClosure: @escaping (Result<T, Error>) -> Void) {
        privateStart(completionClosure)
    }

    func cancel() {
        privateCancel()
    }
}

class LongrunOperation<T>: BaseOperation<T> {
    let longrun: AnyLongrun<T>

    init(longrun: AnyLongrun<T>) {
        self.longrun = longrun
    }

    override func performAsync(_ callback: @escaping (Result<T, Error>) -> Void) throws {
        longrun.start(with: callback)
    }

    override func cancel() {
        longrun.cancel()

        super.cancel()
    }
}

// MARK: - OperationCombiningService

enum OperationCombiningServiceError: Error {
    case alreadyRunningOrFinished
    case noResult
}

public final class OperationCombiningService<T>: Longrunable {
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

        // A faithful copy of a defect in the app original, tracked separately: `.running` was
        // intended here, and because the guard above has already established `.waiting` this
        // assignment leaves the state unchanged, so `cancel()`'s `if state == .running` branch
        // below is unreachable and cancelling the service never cancels the wrappers it
        // combined. Fixing it here would fork the two copies silently and break the rule this
        // file's header states, so it is left exactly as the app has it.
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

    public static func compoundNonOptionalWrapper(
        operationQueue: OperationQueue,
        wrapperClosure: @escaping () throws -> CompoundOperationWrapper<T>
    ) -> CompoundOperationWrapper<T> {
        compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue),
            wrapperClosure: wrapperClosure
        )
    }
}
