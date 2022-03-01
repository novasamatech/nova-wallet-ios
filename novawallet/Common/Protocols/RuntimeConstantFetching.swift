import Foundation
import RobinHood

protocol RuntimeConstantFetching {
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        fallbackValue: T?,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall

    func fetchCompoundConstant<T: Decodable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        fallbackValue: T?,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall
}

extension RuntimeConstantFetching {
    @discardableResult
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        fetchConstant(
            for: path,
            runtimeCodingService: runtimeCodingService,
            operationManager: operationManager,
            fallbackValue: nil,
            closure: closure
        )
    }

    @discardableResult
    func fetchCompoundConstant<T: Decodable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        fetchCompoundConstant(
            for: path,
            runtimeCodingService: runtimeCodingService,
            operationManager: operationManager,
            fallbackValue: nil,
            closure: closure
        )
    }

    @discardableResult
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        fallbackValue: T?,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let constOperation = PrimitiveConstantOperation<T>(path: path, fallbackValue: fallbackValue)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        constOperation.addDependency(codingFactoryOperation)

        constOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = constOperation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [constOperation, codingFactoryOperation], in: .transient)

        return CompoundOperationWrapper(targetOperation: constOperation, dependencies: [codingFactoryOperation])
    }

    @discardableResult
    func fetchCompoundConstant<T: Decodable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        fallbackValue: T?,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let constOperation = StorageConstantOperation<T>(path: path, fallbackValue: fallbackValue)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        constOperation.addDependency(codingFactoryOperation)

        constOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = constOperation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [constOperation, codingFactoryOperation], in: .transient)

        return CompoundOperationWrapper(targetOperation: constOperation, dependencies: [codingFactoryOperation])
    }
}
